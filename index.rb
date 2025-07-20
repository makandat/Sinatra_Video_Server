#!/usr/bin/env ruby
#  ビデオサーバ v4.0
require "sinatra"
require "cgi"
require "json"

# 最初の１回だけ実行される。
configure do
  #set :bind, '0.0.0.0'
  #set :port, 9090
  set :folders, "folders.erb"
  set :environment, :production
  puts "<<< Sinatra ビデオサーバ v4.0 >>>\nhttp:localhost:4567"
end

# ヘルパメソッドの定義
helpers do
  # "folders.txt" を読んで配列として返す。
  def get_folders
    result = Array.new
    File.open("folders.txt") do |file|
      file.each_line do |line1|
        line = line1.strip
        unless line == ""
          result.push(line)
        end
      end
    end
    result.sort!
    return result
  end
  # フォームデータ content をファイル保存する。v4.0
  def post_folders(content)
    File.write("folders.txt", content)
    # 再初期化
  end
  # folders 初期化
  def load_folders()
    # folders.txt の内容
    content = get_folders
    list = JSON.parse(content.to_s)
    folders = ""
    list.each do |item|
      item = item.gsub('\\', '/')
      folders += "#{item}\n"
    end
    return folders
  end
end

# root / の場合
get "/" do
    list = get_folders
    @folders = ""
    list.each do |item|
      @folders += "<li><a href=\"/folder?dir=#{item}\">#{item}</a></li>\n"
    end
    @files = ""
    @path = ""
    @message = ""
    erb :index
end

# ファイル名が指定されたとき
get "/mp4/:filename" do
  @message = ""
  @path = ""
  # ファイル名を得る。
  filename = CGI.unescape(params[:filename])
  #puts filename
  # folders.txt の内容を読んで配列に格納する。
  folders = get_folders
  # そのファイルが存在するか確認
  folders.each do |folder|
    #puts folder
    path = folder
    path.tr!("\\", "/") if RUBY_PLATFORM =~ /win32|mingw|cygwin/
    path << "/#{filename}"
    if FileTest.exist?(path)
      puts "Send: " + path
      @path = path
      send_file path, :disposition => 'inline', :type => 'video/mp4'
      return
    #else
    #  puts "Skiped: " + path
    end
  end
  @message = "エラー： その画像ファイルは存在しない。"
  erb :index
end

# フルパスが指定されたとき
get "/path" do
  @message = ""
  # パス名を得る。
  path = CGI.unescape(params[:path])
  puts path
  # path がファイルかフォルダか判別
  if FileTest.file?(path)
    puts "Send: " + path
    send_file path, :disposition => 'inline', :type => 'video/mp4'
  elsif FileTest::directory?(path)
    # ディレクトリ内の mp4 ファイルを検索する。
    flist = Dir.entries(path)
    files = []
    flist.each do |f|
      if f.end_with?(".mp4")
        files.push(f)
      end
    end
    # ファイル一覧を JSON として返す。
    content_type :json
    files.to_json
  else
    @message = "'#{path}' は存在しない。"
    erb :index
  end
end

# 指定したフォルダ内の動画ファイル一覧を返す。
get "/folder" do
  puts "/folder"
  # フォルダ一覧
  list = get_folders
  @folders = ""
  list.each do |item|
    @folders += "<li><a href=\"/folder?dir=#{item}\">#{item}</a></li>\n"
  end
  # ファイル一覧
  @files = ""
  folder = params[:dir]
  files = Dir.entries(folder)
  files.sort!
  files.each do |file|
    if file[0] == '.' || File.extname(file) != ".mp4"
      next
    end
    @files += "<li><a href=\"/mp4/#{file}\" target=\"_blank\">#{file}</a></li>\n"
  end
  erb :index
end

# GET /edit folders.txt を編集する。v4.0
get "/edit" do
  @folders = load_folders
  erb :folders
end

# POST /edit folders.txt を編集する。v4.0
post "/edit" do
  # フォルダリストを更新する。
  post_folders params[:folders]
  # 表示する
  @message = "フォルダ一覧ファイルが更新されました。"
  @folders = load_folders
  erb :folders
end

# その他の場合
not_found do
  "Bad route found!"
end
