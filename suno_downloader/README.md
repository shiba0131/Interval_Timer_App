# Suno AI 自動ダウンローダー

Suno AIで生成したご自身の曲（My Library）を最新のものから最大30曲、自動的に一括ダウンロードするPythonスクリプトです。

## 注意事項 (Important)
Suno AIには公式APIが存在しないため、ブラウザの通信情報（Cookie）をスクリプトに渡してあげる必要があります。この方法は非公式なものであり、Sunoの仕様変更により予告なく動作しなくなる可能性があります。

## 準備

### 1. Pythonのインストール
お使いのPCにPythonがインストールされていない場合は、[Python公式サイト](https://www.python.org/)からダウンロードしてインストールしてください。

### 2. 必要なライブラリのインストール
コマンドプロンプトまたはPowerShellを開き、このフォルダに移動して以下のコマンドを実行します。
```cmd
pip install -r requirements.txt
```

### 3. Cookie（認証情報）の取得と設定
スクリプトがあなたのアカウントにアクセスできるよう、Cookieを取得します。

1. Google Chrome等のブラウザで [Suno AI](https://suno.com/) にアクセスし、ログインします。
2. ブラウザの開発者ツールを開きます（キーボードの `F12` キーを押します）。
3. 上部のタブから **Network（ネットワーク）** を選びます。
4. Suno AIのページ上で何か適当な操作（例: My Libraryを開く）をします。
5. Networkタブに通信のリストが表示されるので、ドメインが `studio-api.suno.ai` または `suno.com` の通信をどれでも良いので一つクリックします。
6. 右側に表示される詳細から **Headers** タブを選び、**Request Headers** セクションを探します。
7. その中にある **cookie:** の右側の値（非常に長い文字列）をすべてコピーします。
8. ダウンロードした `suno_downloader.py` をメモ帳などのテキストエディタで開き、以下の部分にコピーしたCookieを貼り付けます。

```python
# 変更前
SUNO_COOKIE = "ここにCookieを貼り付けてください"

# 変更後 (例)
SUNO_COOKIE = "suno_session=eyJhb...; __cf_bm=...; ..."
```

## 使い方

1. コマンドプロンプト等で、スクリプトがあるフォルダに移動します。
2. 以下のコマンドを実行します。

```cmd
python suno_downloader.py
```

3. 成功すると、同じフォルダ内に `suno_downloads` というフォルダが作成され、そこにmp3ファイルが順次保存されます。
