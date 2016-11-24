require "crypto/bcrypt/password"
require "logger"
require "kemal"
require "./config.cr"

DEBUG=false

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
  URI.unescape({{name}}.as(String), true)
end

macro body_param(name)
  URI.unescape(env.params.body[{{name}}].as(String), true)
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
    entity = env.session["identity"].to_s()
  else
    entity = "unknown"
  end
  Auditor.instance.info("[" + remote_ip + "] " + entity + ": " + {{txt}})
end

# Returns [ full, web (partial) ]
def sanitized_path(path)
  valid_root = File.expand_path CONFIG["data_root"]
  this_path  = File.expand_path File.join CONFIG["data_root"], unescape_param path
  return ["", ""] unless this_path.starts_with? valid_root
  [this_path, this_path.gsub(valid_root, "")]
end

def prepare(env)
  if DEBUG
    return true
  end
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
  full, partial = sanitized_path location
  return if full == ""
  partial = partial[1..-1] if partial.starts_with?('/')
  current = partial == "" ? "" : URI.escape(partial) + "%2F"
  display_location = URI.unescape location
  files = (Dir.glob full + "/*::" + URI.unescape whoami).map { |x| File.basename x.split(/::/)[0] }.map { |x| { current + x, x } }
  # ".." => holy string parsing batman.
  dirs  = (Dir.entries (full.as(String))).reject { |x| x == "." || (x == ".." && partial == "" || File.basename(x).includes?("::")) }.map { |x|
    x == ".." ? {current.split("%2F")[0..-3].join("%2F"), x} : {current + x, x}
  }

  render "src/views/navigate.ecr", "src/views/layout.ecr"
end

def newsecret(location, whoami)
  display_location = URI.unescape location
  keys = listkeys
  render "src/views/newsecret.ecr", "src/views/layout.ecr"
end

def viewfile(file, whoami)
  location = file.split("/")[0..-2].join("%2F")
  display_location = URI.unescape location
  identity = whoami
  file_name = file

  render "src/views/viewsecret.ecr", "src/views/layout.ecr"
end

def getfile(file, whoami)
  location = file.split("/")[0..-2].join("/")
  display_location = URI.unescape location
  identity = whoami
  file_name = file

puts "GETTING #{display_location}"
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

def pushfile(recipient, location, name, content)
  full, partial = sanitized_path File.join(location, name)
  return if full == ""
  if recipient.includes?('/')
    # F* it...for now
  else
    file_name = full + "::" + recipient
    File.write file_name, content
  end
end

def pullfile(recipient, name)
  full, partial = sanitized_path name
  return if full == ""
  if recipient.includes?('/')
  else
    file_name = full + "::" + recipient
    File.read file_name
  end
end

get "/" do |env|
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

get "/newsecret/:whoami" do |env|
  if prepare(env)
    newsecret "/", env.params.url["whoami"]
  else
    enterpassphrase
  end
end

get "/newsecret/:whoami/:location" do |env|
  if prepare(env)
    newsecret env.params.url["location"], env.params.url["whoami"]
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
    pushfile body_param("recipient"), body_param("location"), body_param("name"), body_param("content")
  end
end

post "/pullfile.json" do |env|
  if prepare(env)
    audit "Pulls file: " + body_param("name")
    pullfile body_param("recipient"), body_param("name")
  end
end

get "/test.json" do |env|
  sanitized_path ""
end
get "/test.json/:path" do |env|
  sanitized_path env.params.url["path"]
end

Kemal.run
