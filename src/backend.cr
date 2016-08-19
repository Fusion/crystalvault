require "kemal"
require "./config.cr"

macro body_param(name)
  URI.unescape(env.params.body[{{name}}] as String, true)
end

macro reply_json(data, diag = 200)
  env.response.content_type = "application/json"
  env.response.status_code = {{diag}}
  {{data}}.to_json
end

macro prepare
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

def listkeys
  (Dir.entries CONFIG["keys_root"]).select { |entry| entry != "." && entry != ".." }
end

def getkey(identity)
  File.read CONFIG["keys_root"] + "/" + identity
end

def pushfile(recipient, name, content)
  if recipient.includes?('/') || name.includes?('/')
    # F* it...for now
  else
    file_name = name + "::" + recipient
    File.write CONFIG["data_root"] + "/" + file_name, content
  end
end

def pullfile(recipient, name)
  if recipient.includes?('/') || name.includes?('/')
  else
    file_name = name + "::" + recipient
    File.read CONFIG["data_root"] + "/" + file_name
  end
end

get "/" do |env|
  prepare
  render "src/views/index.ecr", "src/views/layout.ecr"
end

get "/upkey" do |env|
  prepare
  render "src/views/upkey.ecr", "src/views/layout.ecr"
end

get "/enterpassphrase" do |env|
  prepare
  render "src/views/enterpassphrase.ecr", "src/views/layout.ecr"
end

get "/navigate/:whoami" do |env|
  prepare
  navigate "/", env.params.url["whoami"]
end

get "/navigate/:whoami/:location" do |env|
  prepare
  navigate env.params.url["location"], env.params.url["whoami"]
end

get "/newsecret" do |env|
  prepare
  keys = listkeys
  render "src/views/newsecret.ecr", "src/views/layout.ecr"
end

get "/viewfile/:whoami/:file" do |env|
  prepare
  viewfile env.params.url["file"], env.params.url["whoami"]
end

post "/getkey.json" do |env|
  getkey body_param("id")
end

post "/pushfile.json" do |env|
  pushfile body_param("recipient"), body_param("name"), body_param("content")
end

post "/pullfile.json" do |env|
  pullfile body_param("recipient"), body_param("name")
end

Kemal.run
