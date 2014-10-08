# TaskSync

將不同專案管理系統的 Task 都同步到 Wunderist 集中管理。各種 Asana、Trello、Redmine... 要做的事可不可以不要分散在這麼多地方？

![TaskSync](https://i.imgur.com/geTEy2v.jpg)
<!-- 我只是想在同一個地方看到今天該做的事 -->


## Why Wunderlist?

Wunderlist 有 Day/Week View，具備 Mac、Android、iOS App，管理任務方便，該有的功能都有。


## Features

從各專案管理系統同步待辦事項、產生到期日 ics 行事曆。

### Sync with Asana

可以選擇一個 Project 或一個 Workspace 中被 assign 的任務來同步：

- Name
- Due Date
- Note
- Completed
- Starred (Hearted)

### Sync with Trello

可以選擇一個 Board 或一個 List 的 Card 來同步任務：

- Name
- Due Date
- Note (Description)
- Completed (Archived)
- Starred (Subscribed)


## Setup

同步動作是由 request `/sync?key=your_key` 來觸發，需要用 cron job 或其他服務每幾分鐘對該路徑發 request。

### Local

```bash
$ git clone https://github.com/Neson/TaskSync.git
$ cd TaskSync
$ npm install
```

設置 dotenv 環境變數：

```bash
$ cp .env.example .env
$ vi .env
```

啟動伺服器並監聽 port 8080：

```bash
$ node app.js --port 8080
```

### Deploy to Heroku

```bash
$ git clone https://github.com/Neson/TaskSync.git
$ cd TaskSync
$ heroku apps:create task-sync
$ heroku addons:add heroku-postgresql
$ git push heroku
```

然後到 Heroku 設定環境變數 (參考 `/setup` 和 `.env`)。


## TODO

- Refactor code
- Write tests
- Sync sub-tasks
- Sync with Redmine
