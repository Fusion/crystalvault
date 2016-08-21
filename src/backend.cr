require "crypto/bcrypt/password"
require "logger"
require "kemal"
require "./config.cr"

class Auditor
  INSTANCE = new

  def self.instance
    INSTANCE
  end

  def initialize
    @auditor = Logger.new File.open File.join(CONFIG["logs_root"], "audit.txt"), "a"
    @auditor.level = Logger::INFO
  end

  def info(txt)
    @auditor.info txt
  end
end

macro unescape_param(name)
  URI.unescape({{name}} as String, true)
end

macro body_param(name)
  URI.unescape(env.params.body[{{name}}] as String, true)
end

macro reply_json(data, diag = 200)
  env.response.content_type = "application/json"
  env.response.status_code = {{diag}}
  {{data}}.to_json
end

# Surprisingly, remote_addr is still a unicorn in crystal world
macro audit(txt)
  remote_ip = "IP"
  if env.session["identity"]?
    entity = env.session["identity"]
  else
    entity = "unknown"
  end
  Auditor.instance.info("[" + remote_ip + "] " + entity + ": " + {{txt}})
end

def prepare(env)
  if env.session["identity"]?.is_a?(Nil)
    return false
  end
  true
end

def enterpassphrase
  render "src/views/enterpassphrase.ecr", "src/views/layout.ecr"
end

def navigate(location, whoami)
  # read directory content, based on current user
  # TODO if file contains '::' its name will be truncated...oops
  files = (Dir.glob CONFIG["data_root"] + "/*::" + URI.unescape whoami).map { |x| File.basename x.split(/::/)[0] }

  render "src/views/navigate.ecr", "src/views/layout.ecr"
end

def viewfile(file, whoami)
  identity = whoami
  file_name = file

  render "src/views/viewsecret.ecr", "src/views/layout.ecr"
end

def getfile(file, whoami)
  identity = whoami
  file_name = file

  render "src/views/getsecret.ecr", "src/views/layout.ecr"
end

def listkeys
  (Dir.entries CONFIG["keys_root"]).select { |entry| entry != "." && entry != ".." }
end

# bcrypt creates its own salts
private def encryptpwd(password)
  Crypto::Bcrypt::Password.create password, cost: 10
end

def newuser(identity, password)
  hashed = encryptpwd password
  "Create this file:<br />\n<pre>\necho '#{hashed}' > #{CONFIG["auth_root"]}/#{identity}\n</pre>"
end

def auth(env, identity, password)
  hashed = (File.read File.join(CONFIG["auth_root"], identity)).strip
  stored = Crypto::Bcrypt::Password.new hashed
  if stored == password
    env.session["identity"] = identity
    reply_json({diag: true})
  else
    env.session.delete "identity"
    reply_json({diag: false})
  end
end

def forget(env)
  env.session.delete "identity"
  reply_json({diag: true})
end

def getkey(identity)
  File.read File.join(CONFIG["keys_root"], identity)
end

def pushfile(recipient, name, content)
  if recipient.includes?('/') || name.includes?('/')
    # F* it...for now
  else
    file_name = name + "::" + recipient
    File.write File.join(CONFIG["data_root"], file_name), content
  end
end

def pullfile(recipient, name)
  if recipient.includes?('/') || name.includes?('/')
  else
    file_name = name + "::" + recipient
    File.read File.join(CONFIG["data_root"], file_name)
  end
end

get "/" do |env|
  audit "hello"
  audit "there"
  render "src/views/index.ecr", "src/views/layout.ecr"
end

get "/upkey" do |env|
  if prepare(env)
    render "src/views/upkey.ecr", "src/views/layout.ecr"
  else
    enterpassphrase
  end
end

get "/enterpassphrase" do |env|
  enterpassphrase
end

get "/navigate/:whoami" do |env|
  if prepare(env)
    navigate "/", env.params.url["whoami"]
  else
    enterpassphrase
  end
end

get "/navigate/:whoami/:location" do |env|
  if prepare(env)
    navigate env.params.url["location"], env.params.url["whoami"]
  else
    enterpassphrase
  end
end

get "/newsecret" do |env|
  if prepare(env)
    keys = listkeys
    render "src/views/newsecret.ecr", "src/views/layout.ecr"
  else
    enterpassphrase
  end
end

get "/viewfile/:whoami/:file" do |env|
  if prepare(env)
    viewfile env.params.url["file"], env.params.url["whoami"]
  else
    enterpassphrase
  end
end

get "/getfile/:whoami/:file" do |env|
  if prepare(env)
     getfile unescape_param(env.params.url["file"]), unescape_param(env.params.url["whoami"])
  else
    enterpassphrase
  end
end

get "/newuser.json" do |env|
  "<pre>Syntax: /newuser.json/identity/password -- this will display how to create this user's auth file.</pre>"
end

get "/newuser.json/:identity/:password" do |env|
  newuser env.params.url["identity"], env.params.url["password"]
end

post "/auth.json" do |env|
  auth env, body_param("identity"), body_param("password")
end

post "/forget.json" do |env|
  forget env
end

post "/getkey.json" do |env|
  if prepare(env)
    getkey body_param("id")
  end
end

post "/pushfile.json" do |env|
  if prepare(env)
    audit "Pushes file: " + body_param("name")
    pushfile body_param("recipient"), body_param("name"), body_param("content")
  end
end

post "/pullfile.json" do |env|
  if prepare(env)
    audit "Pulls file: " + body_param("name")
    pullfile body_param("recipient"), body_param("name")
  end
end

Kemal.run
