import json
import sqlite3
import time
from datetime import datetime

import pandas as pd
import streamlit as st

# --- データベース初期化 ---
DB_NAME = "pinpon.db"
TAG_OPTIONS = [
    "サーブミス",
    "レシーブミス",
    "3球目攻撃ミス",
    "ツッツキミス",
    "スピード不足",
    "ドライブミス",
    "ブロックミス",
    "フットワーク",
    "メンタル",
    "戦術ミス",
    "スタミナ切れ",
]


def get_connection():
    return sqlite3.connect(DB_NAME)


def init_db():
    conn = get_connection()
    c = conn.cursor()
    c.execute(
        '''
        CREATE TABLE IF NOT EXISTS matches (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            match_date TEXT,
            tournament_name TEXT,
            opponent_name TEXT,
            opponent_team TEXT,
            play_style TEXT,
            fore_rubber TEXT,
            back_rubber TEXT,
            dominant_hand TEXT,
            racket_grip TEXT,
            game_count INTEGER,
            my_set_count INTEGER,
            opp_set_count INTEGER,
            scores TEXT,
            win_loss_reason TEXT,
            issue_tags TEXT,
            created_at TEXT
        )
        '''
    )
    c.execute(
        '''
        CREATE TABLE IF NOT EXISTS tag_definitions (
            tag_name TEXT PRIMARY KEY,
            is_hidden INTEGER DEFAULT 0,
            sort_order INTEGER,
            created_at TEXT
        )
        '''
    )

    alter_statements = [
        "ALTER TABLE matches ADD COLUMN opponent_team TEXT",
        "ALTER TABLE matches ADD COLUMN fore_rubber TEXT",
        "ALTER TABLE matches ADD COLUMN back_rubber TEXT",
        "ALTER TABLE matches ADD COLUMN racket_grip TEXT",
        "ALTER TABLE matches ADD COLUMN game_count INTEGER",
    ]
    for statement in alter_statements:
        try:
            c.execute(statement)
        except sqlite3.OperationalError:
            pass

    c.execute("UPDATE matches SET racket_grip = 'シェーク' WHERE racket_grip IS NULL OR racket_grip = ''")

    now_text = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    tag_count = c.execute("SELECT COUNT(*) FROM tag_definitions").fetchone()[0]
    if tag_count == 0:
        for index, tag_name in enumerate(TAG_OPTIONS):
            c.execute(
                "INSERT INTO tag_definitions (tag_name, is_hidden, sort_order, created_at) VALUES (?, 0, ?, ?)",
                (tag_name, index, now_text),
            )

    existing_tags = {row[0] for row in c.execute("SELECT tag_name FROM tag_definitions").fetchall()}
    next_sort = c.execute("SELECT COALESCE(MAX(sort_order), -1) + 1 FROM tag_definitions").fetchone()[0]
    for (raw_tags,) in c.execute("SELECT issue_tags FROM matches").fetchall():
        for tag in parse_json_list(raw_tags):
            if tag not in existing_tags:
                c.execute(
                    "INSERT INTO tag_definitions (tag_name, is_hidden, sort_order, created_at) VALUES (?, 0, ?, ?)",
                    (tag, next_sort, now_text),
                )
                existing_tags.add(tag)
                next_sort += 1

    conn.commit()
    conn.close()

# --- スコアからセット数を計算する関数 ---
def calculate_set_count(scores):
    my_sets = 0
    opp_sets = 0
    for my_s, opp_s in scores:
        if my_s == 0 and opp_s == 0:
            continue
        if my_s >= 11 and (my_s - opp_s) >= 2:
            my_sets += 1
        elif opp_s >= 11 and (opp_s - my_s) >= 2:
            opp_sets += 1
        elif my_s > opp_s and (my_s >= 11 or opp_s >= 11):
            my_sets += 1
        elif opp_s > my_s and (my_s >= 11 or opp_s >= 11):
            opp_sets += 1
    return my_sets, opp_sets


# --- スコアのバリデーション関数 ---
def validate_scores(scores, game_count):
    errors = []
    my_sets, opp_sets = calculate_set_count(scores)
    winning_sets_needed = (game_count // 2) + 1
    played_games = 0
    for i, (my_s, opp_s) in enumerate(scores):
        game_num = i + 1
        if my_s == 0 and opp_s == 0:
            continue
        played_games += 1
        if max(my_s, opp_s) < 11:
            errors.append(f"第{game_num}ゲーム: どちらかが11点以上に達している必要があります。")
        elif max(my_s, opp_s) == 11:
            if min(my_s, opp_s) >= 10:
                errors.append(f"第{game_num}ゲーム: 10-10以降は2点差をつける必要があります。")
        elif max(my_s, opp_s) > 11:
            if abs(my_s - opp_s) != 2:
                errors.append(f"第{game_num}ゲーム: 11点以降の決着は必ず2点差になります（例: 12-10, 14-12）。")
    if len(errors) == 0:
        if my_sets < winning_sets_needed and opp_sets < winning_sets_needed:
            errors.append("勝敗がつくまでスコアが入力されていません。")
        elif played_games > (my_sets + opp_sets):
            errors.append("勝敗が決まった後の不要なゲームスコアが入力されています。")
    return errors


# --- 共通処理 ---
def normalize_issue_tags(tags):
    replacements = {
        "ツッツキ浮き": "ツッツキミス",
    }
    return [replacements.get(tag, tag) for tag in tags]


def parse_json_list(value):
    if isinstance(value, list):
        return normalize_issue_tags(value)
    if not value:
        return []
    try:
        parsed = json.loads(value)
        return normalize_issue_tags(parsed) if isinstance(parsed, list) else []
    except (TypeError, json.JSONDecodeError):
        return []


def load_tag_definitions(include_hidden=True):
    conn = get_connection()
    query = "SELECT tag_name, is_hidden, sort_order, created_at FROM tag_definitions"
    if not include_hidden:
        query += " WHERE is_hidden = 0"
    query += " ORDER BY is_hidden ASC, sort_order ASC, tag_name ASC"
    df = pd.read_sql_query(query, conn)
    conn.close()
    if df.empty:
        return []
    return df.to_dict("records")


def load_tag_options(include_hidden=False):
    return [row["tag_name"] for row in load_tag_definitions(include_hidden=include_hidden)]


def load_hidden_tags_set():
    return {row["tag_name"] for row in load_tag_definitions(include_hidden=True) if int(row["is_hidden"]) == 1}


def add_tag_definition(tag_name):
    normalized = tag_name.strip()
    if not normalized:
        return False, "タグ名を入力してください。"

    conn = get_connection()
    c = conn.cursor()
    exists = c.execute("SELECT 1 FROM tag_definitions WHERE tag_name = ?", (normalized,)).fetchone()
    if exists:
        conn.close()
        return False, "同じタグ名がすでに存在します。"

    next_sort = c.execute("SELECT COALESCE(MAX(sort_order), -1) + 1 FROM tag_definitions").fetchone()[0]
    c.execute(
        "INSERT INTO tag_definitions (tag_name, is_hidden, sort_order, created_at) VALUES (?, 0, ?, ?)",
        (normalized, next_sort, datetime.now().strftime("%Y-%m-%d %H:%M:%S")),
    )
    conn.commit()
    conn.close()
    return True, f"タグ「{normalized}」を追加しました。"


def rename_tag_definition(old_name, new_name):
    old_name = old_name.strip()
    new_name = new_name.strip()
    if not old_name or not new_name:
        return False, "変更前と変更後のタグ名を入力してください。"
    if old_name == new_name:
        return False, "変更前と変更後が同じです。"

    conn = get_connection()
    c = conn.cursor()
    if not c.execute("SELECT 1 FROM tag_definitions WHERE tag_name = ?", (old_name,)).fetchone():
        conn.close()
        return False, "変更対象のタグが見つかりません。"
    if c.execute("SELECT 1 FROM tag_definitions WHERE tag_name = ?", (new_name,)).fetchone():
        conn.close()
        return False, "変更後のタグ名はすでに存在します。"

    c.execute("UPDATE tag_definitions SET tag_name = ? WHERE tag_name = ?", (new_name, old_name))
    rows = c.execute("SELECT id, issue_tags FROM matches WHERE issue_tags IS NOT NULL AND issue_tags != ''").fetchall()
    for row_id, raw_tags in rows:
        tags = parse_json_list(raw_tags)
        if old_name in tags:
            updated_tags = [new_name if tag == old_name else tag for tag in tags]
            c.execute("UPDATE matches SET issue_tags = ? WHERE id = ?", (json.dumps(updated_tags, ensure_ascii=False), row_id))

    conn.commit()
    conn.close()
    return True, f"タグ名を「{new_name}」へ変更しました。"


def set_tag_hidden(tag_name, is_hidden):
    conn = get_connection()
    c = conn.cursor()
    if not c.execute("SELECT 1 FROM tag_definitions WHERE tag_name = ?", (tag_name,)).fetchone():
        conn.close()
        return False, "対象タグが見つかりません。"
    c.execute("UPDATE tag_definitions SET is_hidden = ? WHERE tag_name = ?", (1 if is_hidden else 0, tag_name))
    conn.commit()
    conn.close()
    action = "非表示" if is_hidden else "再表示"
    return True, f"タグ「{tag_name}」を{action}にしました。"


def enrich_matches_dataframe(df):
    df = df.copy()
    hidden_tags = load_hidden_tags_set()
    if df.empty:
        df["match_date_dt"] = pd.Series(dtype="datetime64[ns]")
        df["is_win"] = pd.Series(dtype="bool")
        df["result_label"] = pd.Series(dtype="object")
        df["issue_tags_all_list"] = pd.Series(dtype="object")
        df["issue_tags_list"] = pd.Series(dtype="object")
        df["issue_tags_text"] = pd.Series(dtype="object")
        df["racket_grip"] = pd.Series(dtype="object")
        return df

    if "racket_grip" not in df.columns:
        df["racket_grip"] = "シェーク"
    else:
        df["racket_grip"] = df["racket_grip"].fillna("シェーク").replace("", "シェーク")

    df["match_date_dt"] = pd.to_datetime(df["match_date"], errors="coerce")
    df["is_win"] = df["my_set_count"] > df["opp_set_count"]
    df["result_label"] = df.apply(
        lambda row: "勝ち"
        if row["my_set_count"] > row["opp_set_count"]
        else "負け"
        if row["my_set_count"] < row["opp_set_count"]
        else "引き分け",
        axis=1,
    )
    df["issue_tags_all_list"] = df["issue_tags"].apply(parse_json_list)
    df["issue_tags_list"] = df["issue_tags_all_list"].apply(lambda tags: [tag for tag in tags if tag not in hidden_tags])
    df["issue_tags_text"] = df["issue_tags_list"].apply(lambda tags: ", ".join(tags) if tags else "")
    return df


def load_matches_dataframe(order_by="id DESC"):
    conn = sqlite3.connect(DB_NAME)
    df = pd.read_sql_query(f"SELECT * FROM matches ORDER BY {order_by}", conn)
    conn.close()
    return enrich_matches_dataframe(df)


def build_export_dataframe(df):
    columns = [
        "ID",
        "日付",
        "大会名",
        "対戦相手",
        "所属チーム",
        "戦型",
        "利き手",
        "ラケット",
        "フォアラバー",
        "バックラバー",
        "試合形式",
        "勝敗",
        "自分セット",
        "相手セット",
        "課題タグ",
        "勝因・敗因メモ",
        "登録日時",
    ]
    if df.empty:
        return pd.DataFrame(columns=columns)

    export_df = df.copy()
    export_df["ID"] = export_df["id"]
    export_df["日付"] = export_df["match_date"]
    export_df["大会名"] = export_df["tournament_name"]
    export_df["対戦相手"] = export_df["opponent_name"]
    export_df["所属チーム"] = export_df["opponent_team"]
    export_df["戦型"] = export_df["play_style"]
    export_df["利き手"] = export_df["dominant_hand"]
    export_df["ラケット"] = export_df["racket_grip"]
    export_df["フォアラバー"] = export_df["fore_rubber"]
    export_df["バックラバー"] = export_df["back_rubber"]
    export_df["試合形式"] = export_df["game_count"].astype(str) + "ゲームマッチ"
    export_df["勝敗"] = export_df["result_label"]
    export_df["自分セット"] = export_df["my_set_count"]
    export_df["相手セット"] = export_df["opp_set_count"]
    export_df["課題タグ"] = export_df["issue_tags_text"]
    export_df["勝因・敗因メモ"] = export_df["win_loss_reason"]
    export_df["登録日時"] = export_df["created_at"]
    return export_df[columns]


def build_csv_bytes(df):
    return build_export_dataframe(df).to_csv(index=False).encode("utf-8-sig")


def reset_matches_table():
    conn = sqlite3.connect(DB_NAME)
    c = conn.cursor()
    c.execute("DELETE FROM matches")
    conn.commit()
    conn.close()


def load_opponent_profiles():
    conn = sqlite3.connect(DB_NAME)
    query = """
        SELECT opponent_name, opponent_team, play_style, dominant_hand, racket_grip, fore_rubber, back_rubber
        FROM matches
        WHERE opponent_name IS NOT NULL AND opponent_name != ''
        ORDER BY id DESC
    """
    df = pd.read_sql_query(query, conn)
    conn.close()

    profiles = {}
    for _, row in df.iterrows():
        name = row["opponent_name"]
        if name in profiles:
            continue
        profiles[name] = {
            "opponent_name": row["opponent_name"],
            "opponent_team": row["opponent_team"] if pd.notna(row["opponent_team"]) else "",
            "play_style": row["play_style"] if pd.notna(row["play_style"]) else "未選択",
            "dominant_hand": row["dominant_hand"] if pd.notna(row["dominant_hand"]) else "未選択",
            "racket_grip": row["racket_grip"] if pd.notna(row["racket_grip"]) and row["racket_grip"] else "シェーク",
            "fore_rubber": row["fore_rubber"] if pd.notna(row["fore_rubber"]) else "未選択",
            "back_rubber": row["back_rubber"] if pd.notna(row["back_rubber"]) else "未選択",
        }
    return profiles


# --- 登録・編集フォームの描画関数 ---
def render_match_form(default_data=None):
    is_edit = default_data is not None

    def_date = datetime.strptime(default_data["match_date"], "%Y-%m-%d").date() if is_edit and default_data.get("match_date") else datetime.today()
    def_tournament = default_data.get("tournament_name", "") if is_edit else ""
    def_opponent = default_data.get("opponent_name", "") if is_edit else ""
    def_team = default_data.get("opponent_team", "") if is_edit else ""

    def_style = default_data.get("play_style", "未選択") if is_edit else "未選択"
    def_hand = default_data.get("dominant_hand", "未選択") if is_edit else "未選択"
    def_racket_grip = default_data.get("racket_grip", "シェーク") if is_edit else "シェーク"
    def_fore = default_data.get("fore_rubber", "未選択") if is_edit else "未選択"
    def_back = default_data.get("back_rubber", "未選択") if is_edit else "未選択"

    def_game_count = int(default_data.get("game_count", 5)) if is_edit else 5
    def_reason = default_data.get("win_loss_reason", "") if is_edit else ""

    try:
        def_tags = parse_json_list(default_data.get("issue_tags")) if is_edit else []
    except Exception:
        def_tags = []

    try:
        def_scores = parse_json_list(default_data.get("scores")) if is_edit else []
    except Exception:
        def_scores = []

    prefix = f"edit_{default_data['id']}_" if is_edit else "new_"
    field_defaults = {
        prefix + "date": def_date,
        prefix + "tour": def_tournament,
        prefix + "opp": def_opponent,
        prefix + "team": def_team,
        prefix + "style": def_style,
        prefix + "hand": def_hand,
        prefix + "grip": def_racket_grip,
        prefix + "fore": def_fore,
        prefix + "back": def_back,
        prefix + "game_count": def_game_count,
        prefix + "tags": def_tags,
        prefix + "reason": def_reason,
    }
    for state_key, state_value in field_defaults.items():
        if state_key not in st.session_state:
            st.session_state[state_key] = state_value

    tag_options = load_tag_options(include_hidden=False)
    for tag in def_tags:
        if tag not in tag_options:
            tag_options.append(tag)

    opponent_profiles = {}
    preset_key = prefix + "opp_reuse"
    preset_applied_key = prefix + "opp_reuse_applied"
    if not is_edit:
        opponent_profiles = load_opponent_profiles()
        if preset_key not in st.session_state:
            st.session_state[preset_key] = "新しく入力する"
        if preset_applied_key not in st.session_state:
            st.session_state[preset_applied_key] = st.session_state[preset_key]

    with st.container():
        st.markdown("### 基本情報")
        if not is_edit:
            if opponent_profiles:
                preset_options = ["新しく入力する"] + list(opponent_profiles.keys())
                current_preset = st.session_state.get(preset_key, "新しく入力する")
                if current_preset not in preset_options:
                    st.session_state[preset_key] = "新しく入力する"
                selected_profile_name = st.selectbox(
                    "登録済み相手から再利用 (任意)",
                    preset_options,
                    index=preset_options.index(st.session_state[preset_key]),
                    key=preset_key,
                    help="選択すると相手名・所属チーム・戦型・ラバーなどを自動補完します。",
                )
                if selected_profile_name != st.session_state.get(preset_applied_key):
                    st.session_state[preset_applied_key] = selected_profile_name
                    if selected_profile_name != "新しく入力する":
                        profile = opponent_profiles[selected_profile_name]
                        st.session_state[prefix + "opp"] = profile["opponent_name"]
                        st.session_state[prefix + "team"] = profile["opponent_team"]
                        st.session_state[prefix + "style"] = profile["play_style"]
                        st.session_state[prefix + "hand"] = profile["dominant_hand"]
                        st.session_state[prefix + "grip"] = profile["racket_grip"]
                        st.session_state[prefix + "fore"] = profile["fore_rubber"]
                        st.session_state[prefix + "back"] = profile["back_rubber"]
                st.caption("登録済みの相手を選ぶと、相手情報をそのまま再利用できます。")
            else:
                st.caption("登録済みの相手はまだありません。")

        col1, col2 = st.columns(2)
        with col1:
            match_date = st.date_input("日付", value=st.session_state[prefix + "date"], key=prefix + "date")
        with col2:
            tournament_name = st.text_input("大会名", value=st.session_state[prefix + "tour"], placeholder="例: 市民卓球大会", key=prefix + "tour")

        col_opp1, col_opp2 = st.columns(2)
        with col_opp1:
            opponent_name = st.text_input("対戦相手名", value=st.session_state[prefix + "opp"], placeholder="例: 山田 太郎", key=prefix + "opp")
        with col_opp2:
            opponent_team = st.text_input("所属チーム", value=st.session_state[prefix + "team"], placeholder="例: ○○クラブ", key=prefix + "team")

    with st.container():
        st.markdown("### 相手の情報")
        col3, col4, col5 = st.columns(3)
        style_opts = ["未選択", "ドライブ主戦", "前陣速攻", "カットマン", "異質攻守"]
        with col3:
            current_style = st.session_state.get(prefix + "style", "未選択")
            play_style = st.selectbox("戦型", style_opts, index=style_opts.index(current_style) if current_style in style_opts else 0, key=prefix + "style")
        with col4:
            hand_opts = ["未選択", "右利き", "左利き"]
            current_hand = st.session_state.get(prefix + "hand", "未選択")
            dominant_hand = st.selectbox("利き手", hand_opts, index=hand_opts.index(current_hand) if current_hand in hand_opts else 0, key=prefix + "hand")
        with col5:
            grip_opts = ["シェーク", "ペン"]
            current_grip = st.session_state.get(prefix + "grip", "シェーク")
            racket_grip = st.selectbox("ラケット", grip_opts, index=grip_opts.index(current_grip) if current_grip in grip_opts else 0, key=prefix + "grip")

        col_rubber1, col_rubber2 = st.columns(2)
        rubber_options = ["未選択", "裏ソフト", "表ソフト", "粒高", "アンチ", "一枚"]
        with col_rubber1:
            current_fore = st.session_state.get(prefix + "fore", "未選択")
            fore_rubber = st.selectbox("フォアラバー", rubber_options, index=rubber_options.index(current_fore) if current_fore in rubber_options else 0, key=prefix + "fore")
        with col_rubber2:
            current_back = st.session_state.get(prefix + "back", "未選択")
            back_rubber = st.selectbox("バックラバー", rubber_options, index=rubber_options.index(current_back) if current_back in rubber_options else 0, key=prefix + "back")

    with st.container():
        st.markdown("### スコア詳細")
        with st.expander("試合形式の変更 (デフォルト: 5ゲームマッチ)"):
            game_opts = [3, 5, 7]
            current_game_count = st.session_state.get(prefix + "game_count", 5)
            game_count = st.radio(
                "試合形式",
                game_opts,
                index=game_opts.index(current_game_count) if current_game_count in game_opts else 1,
                horizontal=True,
                format_func=lambda x: f"{x}ゲームマッチ",
                label_visibility="collapsed",
                key=prefix + "game_count",
            )

        col_my, col_hyphen, col_opp = st.columns([4, 1, 4])
        with col_my:
            st.markdown("<div style='text-align: center; color: #007bff; font-weight: bold;'>自分</div>", unsafe_allow_html=True)
        with col_opp:
            st.markdown("<div style='text-align: center; color: #dc3545; font-weight: bold;'>相手</div>", unsafe_allow_html=True)

        scores = []
        for i in range(1, game_count + 1):
            def_my_s = def_scores[i - 1][0] if i - 1 < len(def_scores) else 0
            def_opp_s = def_scores[i - 1][1] if i - 1 < len(def_scores) else 0
            col_my, col_hyphen, col_opp = st.columns([4, 1, 4])
            with col_my:
                my_s = st.number_input(f"第{i}ゲーム (自分)", min_value=0, max_value=50, value=int(def_my_s), key=f"{prefix}my_{i}", label_visibility="collapsed")
            with col_hyphen:
                st.markdown("<div style='text-align: center; font-size: 1.5em; color: #6c757d;'>-</div>", unsafe_allow_html=True)
            with col_opp:
                opp_s = st.number_input(f"第{i}ゲーム (相手)", min_value=0, max_value=50, value=int(def_opp_s), key=f"{prefix}opp_{i}", label_visibility="collapsed")
            scores.append((my_s, opp_s))

        my_set_count, opp_set_count = calculate_set_count(scores)

        st.markdown("<br>", unsafe_allow_html=True)
        st.markdown("#### セットカウント")
        st.markdown(
            f"<h2 style='text-align: center; color: #2c3e50;'>自分 <span style='color:#007bff;'>{my_set_count}</span> - <span style='color:#dc3545;'>{opp_set_count}</span> 相手</h2>",
            unsafe_allow_html=True,
        )

    with st.container():
        st.markdown("### 振り返り")
        issue_tags = st.multiselect("課題タグ (複数選択可)", tag_options, default=st.session_state[prefix + "tags"], key=prefix + "tags")
        win_loss_reason = st.text_area(
            "勝因・敗因 / メモ",
            value=st.session_state[prefix + "reason"],
            height=150,
            placeholder="ここに試合の反省点や次への課題を入力してください...",
            key=prefix + "reason",
        )

    st.markdown("<br>", unsafe_allow_html=True)

    submit_clicked = False

    if is_edit:
        col_btn1, col_btn2 = st.columns(2)
        with col_btn1:
            if st.button("変更を保存する", key=prefix + "submit", type="primary", use_container_width=True):
                submit_clicked = True
        with col_btn2:
            if st.button("キャンセル", key=prefix + "cancel", type="secondary", use_container_width=True):
                st.session_state[f"show_edit_{default_data['id']}"] = False
                st.rerun()
    else:
        if st.button("試合結果を登録する", key=prefix + "submit", type="secondary", use_container_width=True):
            submit_clicked = True

    if submit_clicked:
        if not opponent_name:
            st.error("対戦相手名は必須入力です。")
        else:
            errors = validate_scores(scores, game_count)
            if errors:
                for err in errors:
                    st.error(err)
            else:
                try:
                    conn = sqlite3.connect(DB_NAME)
                    c = conn.cursor()
                    scores_json = json.dumps(scores)
                    tags_json = json.dumps(issue_tags)

                    if is_edit:
                        c.execute(
                            '''
                            UPDATE matches SET 
                                match_date=?, tournament_name=?, opponent_name=?, opponent_team=?,
                                play_style=?, fore_rubber=?, back_rubber=?, dominant_hand=?, racket_grip=?, game_count=?, 
                                my_set_count=?, opp_set_count=?, scores=?, win_loss_reason=?, issue_tags=?
                            WHERE id=?
                            ''',
                            (
                                str(match_date),
                                tournament_name,
                                opponent_name,
                                opponent_team,
                                play_style,
                                fore_rubber,
                                back_rubber,
                                dominant_hand,
                                racket_grip,
                                game_count,
                                my_set_count,
                                opp_set_count,
                                scores_json,
                                win_loss_reason,
                                tags_json,
                                default_data["id"],
                            ),
                        )
                        st.success("変更を保存しました！データを更新します...")
                        st.session_state[f"show_edit_{default_data['id']}"] = False
                    else:
                        c.execute(
                            '''
                            INSERT INTO matches (
                                match_date, tournament_name, opponent_name, opponent_team,
                                play_style, fore_rubber, back_rubber, dominant_hand, racket_grip, game_count,
                                my_set_count, opp_set_count, scores, win_loss_reason, issue_tags, created_at
                            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                            ''',
                            (
                                str(match_date),
                                tournament_name,
                                opponent_name,
                                opponent_team,
                                play_style,
                                fore_rubber,
                                back_rubber,
                                dominant_hand,
                                racket_grip,
                                game_count,
                                my_set_count,
                                opp_set_count,
                                scores_json,
                                win_loss_reason,
                                tags_json,
                                datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
                            ),
                        )
                        st.success(f"{opponent_name} 選手との試合結果を登録しました！データを更新します...")
                        st.balloons()

                    conn.commit()
                    conn.close()

                    time.sleep(1.5)
                    st.rerun()
                except Exception as e:
                    st.error(f"エラーが発生しました: {e}")


# --- アプリケーション設定 ---
st.set_page_config(
    page_title="ピンポンの記録",
    page_icon="🏓",
    layout="centered",
    initial_sidebar_state="collapsed",
)

# --- カスタムCSS ---
st.markdown(
    """
<style>
    .stApp { background-color: #f8f9fa; }
    .stButton>button { width: 100%; height: 3em; font-size: 1.2em; font-weight: bold; border-radius: 10px; transition: all 0.3s ease; }
    div[data-testid="stVerticalBlock"] > div[style*="flex-direction: column;"] > div[data-testid="stVerticalBlock"] { background-color: white; padding: 20px; border-radius: 15px; box-shadow: 0 2px 5px rgba(0,0,0,0.05); margin-bottom: 20px; }
    h1, h2, h3, h4 { color: #2c3e50; }
</style>
""",
    unsafe_allow_html=True,
)


# --- メイン処理 ---
def main():
    init_db()

    st.title("🏓 ピンポンの記録")

    tab1, tab2, tab3 = st.tabs(["📖 履歴と編集", "📊 分析・ダッシュボード", "📝 試合結果の登録"])

    # === タブ1: 履歴（詳細閲覧） ===
    with tab1:
        st.subheader("試合履歴の確認")
        try:
            df = load_matches_dataframe(order_by="id DESC")

            if df.empty:
                st.info("履歴がありません。")
            else:
                total_wins = (df["result_label"] == "勝ち").sum()
                total_losses = (df["result_label"] == "負け").sum()
                st.markdown(
                    f"#### 🏆 通算成績: <span style='color:#007bff'>{total_wins}勝</span> - <span style='color:#dc3545'>{total_losses}敗</span>",
                    unsafe_allow_html=True,
                )

                st.markdown("### 🔎 詳細検索")
                valid_dates = df["match_date_dt"].dropna()
                default_date_range = (
                    (valid_dates.min().date(), valid_dates.max().date())
                    if not valid_dates.empty
                    else (datetime.today().date(), datetime.today().date())
                )

                col_f1, col_f2 = st.columns(2)
                with col_f1:
                    search_name = st.text_input("🔍 対戦相手名で検索")
                with col_f2:
                    search_tournament = st.text_input("🏆 大会名で検索")

                col_f3, col_f4 = st.columns(2)
                with col_f3:
                    style_options = ["すべて"] + sorted(df["play_style"].dropna().unique().tolist())
                    search_style = st.selectbox("🏓 戦型で絞り込み", style_options, key="history_search_style")
                with col_f4:
                    search_result = st.selectbox("✅ 勝敗で絞り込み", ["すべて", "勝ち", "負け"], key="history_search_result")

                col_f5, col_f6 = st.columns(2)
                with col_f5:
                    selected_date_range = st.date_input("📅 日付範囲", value=default_date_range)
                with col_f6:
                    search_tags = st.multiselect("🏷️ 課題タグで絞り込み", load_tag_options(include_hidden=False))

                filtered_df = df.copy()
                if search_name:
                    filtered_df = filtered_df[
                        filtered_df["opponent_name"].fillna("").str.contains(search_name, case=False, regex=False)
                    ]
                if search_tournament:
                    filtered_df = filtered_df[
                        filtered_df["tournament_name"].fillna("").str.contains(search_tournament, case=False, regex=False)
                    ]
                if search_style != "すべて":
                    filtered_df = filtered_df[filtered_df["play_style"] == search_style]
                if search_result != "すべて":
                    filtered_df = filtered_df[filtered_df["result_label"] == search_result]
                if isinstance(selected_date_range, (list, tuple)) and len(selected_date_range) == 2:
                    start_date = pd.Timestamp(selected_date_range[0])
                    end_date = pd.Timestamp(selected_date_range[1])
                    filtered_df = filtered_df[
                        filtered_df["match_date_dt"].between(start_date, end_date, inclusive="both")
                    ]
                elif selected_date_range:
                    target_date = pd.Timestamp(selected_date_range)
                    filtered_df = filtered_df[filtered_df["match_date_dt"] == target_date]
                if search_tags:
                    filtered_df = filtered_df[
                        filtered_df["issue_tags_list"].apply(lambda tags: all(tag in tags for tag in search_tags))
                    ]

                filtered_df = filtered_df.reset_index(drop=True)
                st.caption(f"{len(filtered_df)}件 / {len(df)}件 を表示中")

                col_dl1, col_dl2 = st.columns(2)
                with col_dl1:
                    st.download_button(
                        "📥 CSV出力（絞り込み結果）",
                        data=build_csv_bytes(filtered_df),
                        file_name=f"pingpong_record_filtered_{datetime.now():%Y%m%d_%H%M%S}.csv",
                        mime="text/csv",
                        disabled=filtered_df.empty,
                        use_container_width=True,
                    )
                with col_dl2:
                    st.download_button(
                        "📦 CSV出力（全件）",
                        data=build_csv_bytes(df),
                        file_name=f"pingpong_record_all_{datetime.now():%Y%m%d_%H%M%S}.csv",
                        mime="text/csv",
                        use_container_width=True,
                    )

                if filtered_df.empty:
                    st.info("条件に一致する履歴がありません。")
                else:
                    st.markdown("過去の試合を検索し、行を選択すると詳細が表示されます。")
                    display_df = filtered_df[[
                        "id",
                        "match_date",
                        "tournament_name",
                        "opponent_name",
                        "play_style",
                        "result_label",
                        "my_set_count",
                        "opp_set_count",
                    ]].copy()
                    display_df.columns = ["ID", "日付", "大会名", "対戦相手", "戦型", "勝敗", "自分セット", "相手セット"]

                    event = st.dataframe(
                        display_df,
                        use_container_width=True,
                        hide_index=True,
                        on_select="rerun",
                        selection_mode="single-row",
                        key="history_table",
                    )

                    selected_rows = event.selection.rows
                    if selected_rows:
                        selected_idx = selected_rows[0]
                        row = filtered_df.iloc[selected_idx]

                        st.markdown("---")
                        st.markdown(f"### 📋 試合詳細: {row['match_date']} vs {row['opponent_name']}")
                        st.markdown(
                            f"""
                            <div style="background-color: white; padding: 20px; border-radius: 10px; box-shadow: 0 2px 5px rgba(0,0,0,0.05);">
                                <h4 style="margin-top: 0; color: #007bff;">大会・相手情報</h4>
                                <p><b>大会名:</b> {row['tournament_name']} &nbsp;&nbsp; <b>所属チーム:</b> {row['opponent_team']}</p>
                                <p><b>戦型:</b> {row['play_style']} &nbsp;&nbsp; <b>利き手:</b> {row['dominant_hand']} &nbsp;&nbsp; <b>ラケット:</b> {row['racket_grip']}</p>
                                <p><b>フォアラバー:</b> {row['fore_rubber']} &nbsp;&nbsp; <b>バックラバー:</b> {row['back_rubber']}</p>
                            </div>
                            <br>
                            """,
                            unsafe_allow_html=True,
                        )

                        st.markdown("#### 🏓 スコア詳細")
                        st.markdown(f"**セットカウント**: 自分 **{row['my_set_count']} - {row['opp_set_count']}** 相手")
                        scores = parse_json_list(row["scores"])
                        if scores:
                            score_md = ""
                            for i, (my_score, opp_score) in enumerate(scores):
                                if my_score == 0 and opp_score == 0:
                                    continue
                                score_md += f"- 第{i + 1}ゲーム: {my_score} - {opp_score}\n"
                            st.markdown(score_md if score_md else "スコアデータなし")
                        else:
                            st.markdown("スコアデータなし")

                        st.markdown("#### 📝 振り返り")
                        st.markdown(f"**勝敗**: {row['result_label']}")
                        st.markdown(f"**課題タグ**: {row['issue_tags_text'] if row['issue_tags_text'] else 'なし'}")
                        st.markdown(f"**勝因・敗因メモ**:\n\n{row['win_loss_reason']}")

                        st.markdown("---")
                        edit_key = f"show_edit_{row['id']}"
                        del_key = f"show_del_{row['id']}"

                        if not st.session_state.get(edit_key, False) and not st.session_state.get(del_key, False):
                            col_action1, col_action2 = st.columns(2)
                            with col_action1:
                                if st.button("📝 この記録を修正する", key=f"btn_edit_{row['id']}", use_container_width=True):
                                    st.session_state[edit_key] = True
                                    st.rerun()
                            with col_action2:
                                if st.button("🗑️ この記録を削除する", key=f"btn_del_req_{row['id']}", use_container_width=True):
                                    st.session_state[del_key] = True
                                    st.rerun()

                        if st.session_state.get(del_key, False):
                            st.warning("⚠️ 本当にこの試合記録を削除しますか？この操作は元に戻せません。")
                            col_d1, col_d2 = st.columns(2)
                            with col_d1:
                                if st.button("はい、削除します", key=f"btn_del_confirm_{row['id']}", type="primary", use_container_width=True):
                                    try:
                                        conn = sqlite3.connect(DB_NAME)
                                        c = conn.cursor()
                                        c.execute("DELETE FROM matches WHERE id=?", (row["id"],))
                                        conn.commit()
                                        conn.close()
                                        if "history_table" in st.session_state:
                                            del st.session_state["history_table"]
                                        st.success("試合記録を削除しました！データを更新します...")
                                        time.sleep(1.5)
                                        st.rerun()
                                    except Exception as e:
                                        st.error(f"削除中にエラーが発生しました: {e}")
                            with col_d2:
                                if st.button("キャンセル", key=f"btn_del_cancel_{row['id']}", use_container_width=True):
                                    st.session_state[del_key] = False
                                    st.rerun()

                        if st.session_state.get(edit_key, False):
                            st.markdown("#### 📝 記録の修正")
                            render_match_form(row.to_dict())

            st.markdown("---")
            with st.expander("データ管理", expanded=False):
                st.caption("通常は使いません。必要な場合のみデータベース初期化を実行してください。")
                reset_key = "show_reset_db_confirm"
                if not st.session_state.get(reset_key, False):
                    if st.button("データベース初期化", key="btn_show_reset_db", use_container_width=True):
                        st.session_state[reset_key] = True
                        st.rerun()
                else:
                    st.warning("データベースを初期化すると、すべての試合記録が削除されます。")
                    col_r1, col_r2 = st.columns(2)
                    with col_r1:
                        if st.button("はい、初期化します", key="btn_reset_db_confirm", type="primary", use_container_width=True):
                            try:
                                reset_matches_table()
                                if "history_table" in st.session_state:
                                    del st.session_state["history_table"]
                                for state_key in list(st.session_state.keys()):
                                    if state_key.startswith("show_edit_") or state_key.startswith("show_del_"):
                                        del st.session_state[state_key]
                                st.session_state[reset_key] = False
                                st.success("データベースを初期化しました。データを更新します...")
                                time.sleep(1.5)
                                st.rerun()
                            except Exception as e:
                                st.error(f"データベース初期化中にエラーが発生しました: {e}")
                    with col_r2:
                        if st.button("キャンセル", key="btn_reset_db_cancel", use_container_width=True):
                            st.session_state[reset_key] = False
                            st.rerun()

        except Exception as e:
            st.error(f"履歴データの読み込みに失敗しました: {e}")

    # === タブ2: 分析・ダッシュボード ===
    with tab2:
        st.subheader("分析・ダッシュボード")
        try:
            df = load_matches_dataframe(order_by="id ASC")
            tag_notice = st.session_state.pop("tag_mgmt_notice", None) if "tag_mgmt_notice" in st.session_state else None
            if tag_notice:
                st.success(tag_notice)

            if df.empty:
                st.info("データがありません。試合結果を登録すると分析が表示されます。")
            else:
                st.markdown("### 🏆 戦型別 勝率 (%)")
                style_df = df[df["play_style"] != "未選択"]
                if not style_df.empty:
                    win_rate_style = (style_df.groupby("play_style")["is_win"].mean() * 100).round(1)
                    st.bar_chart(win_rate_style)
                else:
                    st.write("データ不足")

                st.markdown("---")
                st.markdown("### 😓 苦手戦型")
                if not style_df.empty:
                    difficult_styles = style_df.groupby("play_style").agg(試合数=("id", "count"), 勝ち=("is_win", "sum"))
                    difficult_styles["負け"] = difficult_styles["試合数"] - difficult_styles["勝ち"]
                    difficult_styles["勝率(%)"] = (difficult_styles["勝ち"] / difficult_styles["試合数"] * 100).round(1)
                    difficult_styles = difficult_styles[["試合数", "勝ち", "負け", "勝率(%)"]].sort_values(["勝率(%)", "試合数"], ascending=[True, False])
                    st.dataframe(difficult_styles, use_container_width=True)
                    st.caption("勝率が低い順です。試合数が多く勝率が低い戦型ほど重点対策候補です。")
                else:
                    st.write("データ不足")

                st.markdown("---")
                st.markdown("### 📈 課題タグ集計")
                limit_opts = [5, 10, 20, 50, 100, 9999]
                limit = st.selectbox(
                    "集計対象の試合数",
                    limit_opts,
                    index=1,
                    format_func=lambda x: "すべて" if x == 9999 else f"直近 {x} 試合",
                    key="analysis_tag_limit",
                )
                recent_matches = df.sort_values(["match_date_dt", "id"], ascending=[False, False], na_position="last").head(limit)
                tags_list = []
                for tags in recent_matches["issue_tags_list"]:
                    tags_list.extend(tags)
                disp_text = "全試合" if limit == 9999 else f"直近{limit}試合"
                if tags_list:
                    tag_counts = pd.Series(tags_list).value_counts()
                    st.bar_chart(tag_counts)
                    st.caption(f"{disp_text}で出現した課題タグの回数です。指導や練習の重点項目の決定に役立ててください。")
                else:
                    st.write(f"{disp_text}に課題タグの記録がありません。")

                st.markdown("---")
                st.markdown("### 📉 直近10試合の勝敗推移")
                recent_outcomes = df.sort_values(["match_date_dt", "id"], ascending=[True, True], na_position="last").tail(10).copy()
                if not recent_outcomes.empty:
                    recent_outcomes["試合"] = recent_outcomes.apply(lambda row: f"{row['match_date']} vs {row['opponent_name']}", axis=1)
                    recent_outcomes["勝敗指標"] = recent_outcomes["result_label"].map({"勝ち": 1, "負け": 0, "引き分け": 0.5})
                    st.line_chart(recent_outcomes.set_index("試合")[["勝敗指標"]])
                    st.caption("1 が勝ち、0 が負けです。")
                else:
                    st.write("データ不足")

                st.markdown("---")
                st.markdown("### 🗓️ 月別勝率")
                monthly_df = df.dropna(subset=["match_date_dt"]).copy()
                if not monthly_df.empty:
                    monthly_df["年月"] = monthly_df["match_date_dt"].dt.strftime("%Y-%m")
                    monthly_win_rate = (monthly_df.groupby("年月")["is_win"].mean() * 100).round(1)
                    st.line_chart(monthly_win_rate)
                    st.caption("月ごとの勝率推移です。")
                else:
                    st.write("日付データ不足")

                st.markdown("---")
                st.markdown("### 🏷️ 課題タグの月別推移")
                tag_trend_df = df.dropna(subset=["match_date_dt"]).copy().explode("issue_tags_list")
                tag_trend_df = tag_trend_df[tag_trend_df["issue_tags_list"].notna() & (tag_trend_df["issue_tags_list"] != "")]
                if not tag_trend_df.empty:
                    tag_trend_df["年月"] = tag_trend_df["match_date_dt"].dt.strftime("%Y-%m")
                    top_tags = tag_trend_df["issue_tags_list"].value_counts().head(5).index.tolist()
                    tag_month_counts = (
                        tag_trend_df[tag_trend_df["issue_tags_list"].isin(top_tags)]
                        .groupby(["年月", "issue_tags_list"])
                        .size()
                        .unstack(fill_value=0)
                    )
                    st.line_chart(tag_month_counts)
                    st.caption("出現回数が多い上位5タグの月別推移です。")
                else:
                    st.write("課題タグの時系列データがありません。")

                st.markdown("---")
                st.markdown("### 🤝 対戦相手別 通算成績")
                opponent_df = df[df["opponent_name"].fillna("") != ""].copy()
                if not opponent_df.empty:
                    opponent_summary = opponent_df.groupby("opponent_name").agg(
                        試合数=("id", "count"),
                        勝ち=("is_win", "sum"),
                        最新日=("match_date", "max"),
                        主な戦型=("play_style", lambda s: s.mode().iloc[0] if not s.mode().empty else "未選択"),
                    )
                    opponent_summary["負け"] = opponent_summary["試合数"] - opponent_summary["勝ち"]
                    opponent_summary["勝率(%)"] = (opponent_summary["勝ち"] / opponent_summary["試合数"] * 100).round(1)
                    opponent_summary = opponent_summary[["試合数", "勝ち", "負け", "勝率(%)", "主な戦型", "最新日"]].sort_values(["試合数", "勝率(%)"], ascending=[False, True])
                    st.dataframe(opponent_summary, use_container_width=True)

                    selected_opponent = st.selectbox("詳細を見る対戦相手", opponent_summary.index.tolist(), key="analysis_selected_opponent")
                    selected_opponent_df = opponent_df[opponent_df["opponent_name"] == selected_opponent].sort_values(["match_date_dt", "id"])
                    wins = int((selected_opponent_df["result_label"] == "勝ち").sum())
                    losses = int((selected_opponent_df["result_label"] == "負け").sum())
                    matches = len(selected_opponent_df)
                    win_rate = round((wins / matches) * 100, 1) if matches else 0
                    col_m1, col_m2, col_m3, col_m4 = st.columns(4)
                    col_m1.metric("試合数", matches)
                    col_m2.metric("勝ち", wins)
                    col_m3.metric("負け", losses)
                    col_m4.metric("勝率", f"{win_rate}%")

                    selected_opponent_df = selected_opponent_df.copy()
                    selected_opponent_df["対戦"] = selected_opponent_df.apply(lambda row: f"{row['match_date']} ({row['result_label']})", axis=1)
                    selected_opponent_df["累計勝ち"] = (selected_opponent_df["result_label"] == "勝ち").cumsum()
                    selected_opponent_df["累計負け"] = (selected_opponent_df["result_label"] == "負け").cumsum()
                    st.line_chart(selected_opponent_df.set_index("対戦")[["累計勝ち", "累計負け"]])
                    st.caption("同じ相手との通算勝敗の推移です。")

                    loss_df = selected_opponent_df[selected_opponent_df["result_label"] == "負け"].copy()
                    if not loss_df.empty:
                        st.markdown("#### 負けパターン")
                        loss_tags_df = loss_df.explode("issue_tags_list")
                        loss_tags_df = loss_tags_df[loss_tags_df["issue_tags_list"].notna() & (loss_tags_df["issue_tags_list"] != "")]
                        if not loss_tags_df.empty:
                            loss_tag_counts = loss_tags_df["issue_tags_list"].value_counts()
                            st.bar_chart(loss_tag_counts)
                        else:
                            st.write("負け試合の課題タグ記録はありません。")

                        notes = [note for note in loss_df["win_loss_reason"].fillna("").tolist() if note.strip()]
                        if notes:
                            st.markdown("#### 敗戦メモ")
                            for note in notes[-3:]:
                                st.markdown(f"- {note}")
                    else:
                        st.write("この相手にはまだ負けていません。")
                else:
                    st.write("対戦相手データがありません。")

            st.markdown("---")
            with st.expander("🏷️ 課題タグ管理", expanded=False):
                st.caption("タグの追加、名称変更、非表示・再表示を行えます。非表示タグは新規入力や検索候補から外れます。")
                tag_definitions = load_tag_definitions(include_hidden=True)
                visible_tags = [row["tag_name"] for row in tag_definitions if int(row["is_hidden"]) == 0]
                hidden_tags = [row["tag_name"] for row in tag_definitions if int(row["is_hidden"]) == 1]

                col_t1, col_t2 = st.columns(2)
                with col_t1:
                    st.markdown("#### 表示中タグ")
                    st.write("、".join(visible_tags) if visible_tags else "なし")
                with col_t2:
                    st.markdown("#### 非表示タグ")
                    st.write("、".join(hidden_tags) if hidden_tags else "なし")

                st.markdown("#### タグ追加")
                new_tag_name = st.text_input("新しいタグ名", key="tag_add_name")
                if st.button("タグを追加", key="btn_tag_add", use_container_width=True):
                    success, message = add_tag_definition(new_tag_name)
                    if success:
                        st.session_state["tag_mgmt_notice"] = message
                        st.rerun()
                    else:
                        st.error(message)

                st.markdown("#### タグ名変更")
                rename_candidates = [row["tag_name"] for row in tag_definitions]
                if rename_candidates:
                    rename_from = st.selectbox("変更対象タグ", rename_candidates, key="tag_rename_from")
                    rename_to = st.text_input("変更後のタグ名", key="tag_rename_to")
                    if st.button("名称を変更", key="btn_tag_rename", use_container_width=True):
                        success, message = rename_tag_definition(rename_from, rename_to)
                        if success:
                            st.session_state["tag_mgmt_notice"] = message
                            st.rerun()
                        else:
                            st.error(message)
                else:
                    st.write("変更できるタグがありません。")

                st.markdown("#### タグの表示設定")
                col_h1, col_h2 = st.columns(2)
                with col_h1:
                    if visible_tags:
                        hide_target = st.selectbox("非表示にするタグ", visible_tags, key="tag_hide_target")
                        if st.button("非表示にする", key="btn_tag_hide", use_container_width=True):
                            success, message = set_tag_hidden(hide_target, True)
                            if success:
                                st.session_state["tag_mgmt_notice"] = message
                                st.rerun()
                            else:
                                st.error(message)
                    else:
                        st.write("非表示にできるタグがありません。")
                with col_h2:
                    if hidden_tags:
                        unhide_target = st.selectbox("再表示するタグ", hidden_tags, key="tag_unhide_target")
                        if st.button("再表示する", key="btn_tag_unhide", use_container_width=True):
                            success, message = set_tag_hidden(unhide_target, False)
                            if success:
                                st.session_state["tag_mgmt_notice"] = message
                                st.rerun()
                            else:
                                st.error(message)
                    else:
                        st.write("非表示中のタグはありません。")
        except Exception as e:
            st.error(f"分析データの読み込みに失敗しました: {e}")

    # === タブ3: 試合結果の登録 ===
    with tab3:
        st.subheader("試合結果の登録")
        render_match_form()


if __name__ == "__main__":
    main()
