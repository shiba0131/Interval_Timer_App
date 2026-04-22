import streamlit as st
import sqlite3
from datetime import datetime
import json
import pandas as pd

# --- データベース初期化 ---
DB_NAME = "pinpon.db"

def init_db():
    conn = sqlite3.connect(DB_NAME)
    c = conn.cursor()
    c.execute('''
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
            game_count INTEGER,
            my_set_count INTEGER,
            opp_set_count INTEGER,
            scores TEXT,
            win_loss_reason TEXT,
            issue_tags TEXT,
            created_at TEXT
        )
    ''')
    # 既存のテーブルにカラムを追加する簡易マイグレーション
    try:
        c.execute('ALTER TABLE matches ADD COLUMN opponent_team TEXT')
        c.execute('ALTER TABLE matches ADD COLUMN fore_rubber TEXT')
        c.execute('ALTER TABLE matches ADD COLUMN back_rubber TEXT')
        c.execute('ALTER TABLE matches ADD COLUMN game_count INTEGER')
    except sqlite3.OperationalError:
        pass
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

# --- 登録・編集フォームの描画関数 ---
def render_match_form(default_data=None):
    is_edit = default_data is not None
    
    # デフォルト値の設定
    def_date = datetime.strptime(default_data['match_date'], '%Y-%m-%d').date() if is_edit and default_data.get('match_date') else datetime.today()
    def_tournament = default_data.get('tournament_name', '') if is_edit else ''
    def_opponent = default_data.get('opponent_name', '') if is_edit else ''
    def_team = default_data.get('opponent_team', '') if is_edit else ''
    
    def_style = default_data.get('play_style', '未選択') if is_edit else '未選択'
    def_hand = default_data.get('dominant_hand', '未選択') if is_edit else '未選択'
    def_fore = default_data.get('fore_rubber', '未選択') if is_edit else '未選択'
    def_back = default_data.get('back_rubber', '未選択') if is_edit else '未選択'
    
    def_game_count = int(default_data.get('game_count', 5)) if is_edit else 5
    def_reason = default_data.get('win_loss_reason', '') if is_edit else ''
    
    try:
        def_tags = json.loads(default_data['issue_tags']) if is_edit and default_data.get('issue_tags') else []
    except:
        def_tags = []
        
    try:
        def_scores = json.loads(default_data['scores']) if is_edit and default_data.get('scores') else []
    except:
        def_scores = []

    # UIコンポーネントが重複しないようにユニークなキーを付与
    prefix = f"edit_{default_data['id']}_" if is_edit else "new_"

    with st.container():
        st.markdown("### 基本情報")
        col1, col2 = st.columns(2)
        with col1:
            match_date = st.date_input("日付", def_date, key=prefix+"date")
        with col2:
            tournament_name = st.text_input("大会名", value=def_tournament, placeholder="例: 市民卓球大会", key=prefix+"tour")
        
        col_opp1, col_opp2 = st.columns(2)
        with col_opp1:
            opponent_name = st.text_input("対戦相手名", value=def_opponent, placeholder="例: 山田 太郎", key=prefix+"opp")
        with col_opp2:
            opponent_team = st.text_input("所属チーム", value=def_team, placeholder="例: ○○クラブ", key=prefix+"team")

    with st.container():
        st.markdown("### 相手の情報")
        col3, col4 = st.columns(2)
        style_opts = ["未選択", "ドライブ主戦", "前陣速攻", "カットマン", "異質攻守"]
        with col3:
            play_style = st.selectbox("戦型", style_opts, index=style_opts.index(def_style) if def_style in style_opts else 0, key=prefix+"style")
        with col4:
            hand_opts = ["未選択", "右利き", "左利き"]
            dominant_hand = st.selectbox("利き手", hand_opts, index=hand_opts.index(def_hand) if def_hand in hand_opts else 0, key=prefix+"hand")

        col_rubber1, col_rubber2 = st.columns(2)
        rubber_options = ["未選択", "裏ソフト", "表ソフト", "粒高", "アンチ", "一枚"]
        with col_rubber1:
            fore_rubber = st.selectbox("フォアラバー", rubber_options, index=rubber_options.index(def_fore) if def_fore in rubber_options else 0, key=prefix+"fore")
        with col_rubber2:
            back_rubber = st.selectbox("バックラバー", rubber_options, index=rubber_options.index(def_back) if def_back in rubber_options else 0, key=prefix+"back")

    with st.container():
        st.markdown("### スコア詳細")
        with st.expander("試合形式の変更 (デフォルト: 5ゲームマッチ)"):
            game_opts = [3, 5, 7]
            game_count = st.radio("試合形式", game_opts, index=game_opts.index(def_game_count) if def_game_count in game_opts else 1, horizontal=True, format_func=lambda x: f"{x}ゲームマッチ", label_visibility="collapsed", key=prefix+"game_count")
        
        col_my, col_hyphen, col_opp = st.columns([4, 1, 4])
        with col_my:
            st.markdown("<div style='text-align: center; color: #007bff; font-weight: bold;'>自分</div>", unsafe_allow_html=True)
        with col_opp:
            st.markdown("<div style='text-align: center; color: #dc3545; font-weight: bold;'>相手</div>", unsafe_allow_html=True)

        scores = []
        for i in range(1, game_count + 1):
            def_my_s = def_scores[i-1][0] if i-1 < len(def_scores) else 0
            def_opp_s = def_scores[i-1][1] if i-1 < len(def_scores) else 0
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
        st.markdown(f"<h2 style='text-align: center; color: #2c3e50;'>自分 <span style='color:#007bff;'>{my_set_count}</span> - <span style='color:#dc3545;'>{opp_set_count}</span> 相手</h2>", unsafe_allow_html=True)

    with st.container():
        st.markdown("### 振り返り")
        tag_options = ["サーブミス", "レシーブミス", "3球目攻撃ミス", "ツッツキミス", "ドライブミス", "ブロックミス", "フットワーク", "メンタル", "戦術ミス", "スタミナ切れ"]
        def_tags = [t for t in def_tags if t in tag_options]
        issue_tags = st.multiselect("課題タグ (複数選択可)", tag_options, default=def_tags, key=prefix+"tags")
        win_loss_reason = st.text_area("勝因・敗因 / メモ", value=def_reason, height=150, placeholder="ここに試合の反省点や次への課題を入力してください...", key=prefix+"reason")

    st.markdown("<br>", unsafe_allow_html=True)
    
    submit_clicked = False
    
    if is_edit:
        col_btn1, col_btn2 = st.columns(2)
        with col_btn1:
            if st.button("変更を保存する", key=prefix+"submit", type="primary", use_container_width=True):
                submit_clicked = True
        with col_btn2:
            if st.button("キャンセル", key=prefix+"cancel", type="secondary", use_container_width=True):
                st.session_state[f"show_edit_{default_data['id']}"] = False
                st.rerun()
    else:
        if st.button("試合結果を登録する", key=prefix+"submit", type="secondary", use_container_width=True):
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
                        c.execute('''
                            UPDATE matches SET 
                                match_date=?, tournament_name=?, opponent_name=?, opponent_team=?,
                                play_style=?, fore_rubber=?, back_rubber=?, dominant_hand=?, game_count=?, 
                                my_set_count=?, opp_set_count=?, scores=?, win_loss_reason=?, issue_tags=?
                            WHERE id=?
                        ''', (
                            str(match_date), tournament_name, opponent_name, opponent_team,
                            play_style, fore_rubber, back_rubber, dominant_hand, game_count,
                            my_set_count, opp_set_count, scores_json, win_loss_reason, tags_json,
                            default_data['id']
                        ))
                        st.success("変更を保存しました！データを更新します...")
                        st.session_state[f"show_edit_{default_data['id']}"] = False
                    else:
                        c.execute('''
                            INSERT INTO matches (
                                match_date, tournament_name, opponent_name, opponent_team,
                                play_style, fore_rubber, back_rubber, dominant_hand, game_count, 
                                my_set_count, opp_set_count, scores, win_loss_reason, issue_tags, created_at
                            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                        ''', (
                            str(match_date), tournament_name, opponent_name, opponent_team,
                            play_style, fore_rubber, back_rubber, dominant_hand, game_count,
                            my_set_count, opp_set_count, scores_json, win_loss_reason, tags_json, 
                            datetime.now().strftime("%Y-%m-%d %H:%M:%S")
                        ))
                        st.success(f"{opponent_name} 選手との試合結果を登録しました！データを更新します...")
                        st.balloons()
                    
                    conn.commit()
                    conn.close()
                    
                    import time
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
st.markdown("""
<style>
    .stApp { background-color: #f8f9fa; }
    .stButton>button { width: 100%; height: 3em; font-size: 1.2em; font-weight: bold; border-radius: 10px; transition: all 0.3s ease; }
    div[data-testid="stVerticalBlock"] > div[style*="flex-direction: column;"] > div[data-testid="stVerticalBlock"] { background-color: white; padding: 20px; border-radius: 15px; box-shadow: 0 2px 5px rgba(0,0,0,0.05); margin-bottom: 20px; }
    h1, h2, h3, h4 { color: #2c3e50; }
</style>
""", unsafe_allow_html=True)

# --- メイン処理 ---
def main():
    init_db()

    st.title("🏓 ピンポンの記録")
    
    tab1, tab2, tab3 = st.tabs(["📖 履歴と編集", "📊 分析・ダッシュボード", "📝 試合結果の登録"])
    
    # === タブ3: 試合結果の登録 ===
    with tab3:
        st.subheader("試合結果の登録")
        render_match_form()

    # === タブ2: 分析・ダッシュボード ===
    with tab2:
        st.subheader("分析・ダッシュボード")
        try:
            conn = sqlite3.connect(DB_NAME)
            df = pd.read_sql_query("SELECT * FROM matches", conn)
            conn.close()
            
            if df.empty:
                st.info("データがありません。試合結果を登録すると分析が表示されます。")
            else:
                df['is_win'] = df['my_set_count'] > df['opp_set_count']
                
                st.markdown("### 🏆 戦型別 勝率 (%)")
                style_df = df[df['play_style'] != '未選択']
                if not style_df.empty:
                    win_rate_style = style_df.groupby('play_style')['is_win'].mean() * 100
                    st.bar_chart(win_rate_style)
                else:
                    st.write("データ不足")
                        
                st.markdown("---")
                st.markdown("### 📈 課題タグ集計")
                
                limit_opts = [5, 10, 20, 50, 100, 9999]
                limit = st.selectbox("集計対象の試合数", limit_opts, index=1, format_func=lambda x: "すべて" if x == 9999 else f"直近 {x} 試合")
                
                recent_matches = df.sort_values('id', ascending=False).head(limit)
                
                tags_list = []
                for tags_str in recent_matches['issue_tags']:
                    if tags_str:
                        try:
                            tags = json.loads(tags_str)
                            tags_list.extend(tags)
                        except:
                            pass
                
                disp_text = "全試合" if limit == 9999 else f"直近{limit}試合"
                
                if tags_list:
                    tag_counts = pd.Series(tags_list).value_counts()
                    st.bar_chart(tag_counts)
                    st.caption(f"{disp_text}で出現した課題タグの回数です。指導や練習の重点項目の決定に役立ててください。")
                else:
                    st.write(f"{disp_text}に課題タグの記録がありません。")
        except Exception as e:
            st.error(f"分析データの読み込みに失敗しました: {e}")

    # === タブ1: 履歴（詳細閲覧） ===
    with tab1:
        st.subheader("試合履歴の確認")
        try:
            conn = sqlite3.connect(DB_NAME)
            df = pd.read_sql_query("SELECT * FROM matches ORDER BY id DESC", conn)
            conn.close()
            
            if df.empty:
                st.info("履歴がありません。")
            else:
                total_wins = (df['my_set_count'] > df['opp_set_count']).sum()
                total_losses = (df['my_set_count'] < df['opp_set_count']).sum()
                st.markdown(f"#### 🏆 通算成績: <span style='color:#007bff'>{total_wins}勝</span> - <span style='color:#dc3545'>{total_losses}敗</span>", unsafe_allow_html=True)
                
                st.markdown("過去の試合を検索し、行を選択すると詳細が表示されます。")
                
                col_f1, col_f2 = st.columns(2)
                with col_f1:
                    search_name = st.text_input("🔍 対戦相手名で検索")
                with col_f2:
                    search_style = st.selectbox("🏓 戦型で絞り込み", ["すべて"] + list(df['play_style'].unique()))
                    
                filtered_df = df.copy()
                if search_name:
                    filtered_df = filtered_df[filtered_df['opponent_name'].str.contains(search_name, na=False)]
                if search_style != "すべて":
                    filtered_df = filtered_df[filtered_df['play_style'] == search_style]
                    
                display_df = filtered_df[['id', 'match_date', 'tournament_name', 'opponent_name', 'play_style', 'my_set_count', 'opp_set_count']]
                display_df.columns = ['ID', '日付', '大会名', '対戦相手', '戦型', '自分セット', '相手セット']
                
                event = st.dataframe(
                    display_df, 
                    use_container_width=True, 
                    hide_index=True,
                    on_select="rerun",
                    selection_mode="single-row",
                    key="history_table"
                )
                
                selected_rows = event.selection.rows
                if selected_rows:
                    selected_idx = selected_rows[0]
                    row = filtered_df.iloc[selected_idx]
                    
                    st.markdown("---")
                    st.markdown(f"### 📋 試合詳細: {row['match_date']} vs {row['opponent_name']}")
                    
                    st.markdown(f"""
                    <div style="background-color: white; padding: 20px; border-radius: 10px; box-shadow: 0 2px 5px rgba(0,0,0,0.05);">
                        <h4 style="margin-top: 0; color: #007bff;">大会・相手情報</h4>
                        <p><b>大会名:</b> {row['tournament_name']} &nbsp;&nbsp; <b>所属チーム:</b> {row['opponent_team']}</p>
                        <p><b>戦型:</b> {row['play_style']} &nbsp;&nbsp; <b>利き手:</b> {row['dominant_hand']}</p>
                        <p><b>フォアラバー:</b> {row['fore_rubber']} &nbsp;&nbsp; <b>バックラバー:</b> {row['back_rubber']}</p>
                    </div>
                    <br>
                    """, unsafe_allow_html=True)
                        
                    st.markdown("#### 🏓 スコア詳細")
                    st.markdown(f"**セットカウント**: 自分 **{row['my_set_count']} - {row['opp_set_count']}** 相手")
                    try:
                        scores = json.loads(row['scores'])
                        score_md = ""
                        for i, (m_s, o_s) in enumerate(scores):
                            if m_s == 0 and o_s == 0: continue
                            score_md += f"- 第{i+1}ゲーム: {m_s} - {o_s}\n"
                        st.markdown(score_md)
                    except:
                        st.markdown("スコアデータなし")
                        
                    st.markdown("#### 📝 振り返り")
                    try:
                        tags = json.loads(row['issue_tags'])
                        if tags:
                            st.markdown(f"**課題タグ**: {', '.join(tags)}")
                        else:
                            st.markdown("**課題タグ**: なし")
                    except:
                        pass
                        
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
                                    c.execute("DELETE FROM matches WHERE id=?", (row['id'],))
                                    conn.commit()
                                    conn.close()
                                    if "history_table" in st.session_state:
                                        del st.session_state["history_table"]
                                    st.success("試合記録を削除しました！データを更新します...")
                                    import time
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
                    
        except Exception as e:
            st.error(f"履歴データの読み込みに失敗しました: {e}")

if __name__ == "__main__":
    main()



