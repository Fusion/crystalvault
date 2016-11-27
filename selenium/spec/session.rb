require "selenium-webdriver"
require "yaml"

# Assumptions:
#
# Current data/data structure:
#
# /
# |-demo/
#       |- testfile.txt
#       |- personal/
#       |- sub/
#             |- testfile.txt
#             |- sub2/
#                    |- sub3/
#
# textfile.txt contains string 'TODO' at least once

class TestSuite
end

describe TestSuite do
    before (:context) do
        # username, password, passphrase, root
        @config = YAML.load_file "config.yml"

        @browser = Selenium::WebDriver.for :phantomjs
        @browser.manage.window.size = Selenium::WebDriver::Dimension.new(1280, 1024)
    end

    after(:context) do
        @browser.close
        @browser.quit
    end

    describe "open app" do
        it "opens the main web page" do
            @browser.get @config["root"]
            @browser.find_element(id: "navigate_menu")
            #expect("hello").to eq("hello")
        end

        it "opens passphrase page" do
            @browser.get "#{@config["root"]}/upkey"
            @browser.find_element(id: "email")
            @browser.find_element(id: "password")
            @browser.find_element(id: "passphrase")
            @browser.find_element(id: "howlong")
            @browser.find_element(id: "submitter")
            #expect("hello").to eq("hello")
        end

        it "logs in" do
            @browser["email"].send_keys(@config["username"])
            @browser["password"].send_keys(@config["password"])
            @browser["passphrase"].send_keys(@config["passphrase"])
            @browser.action.double_click(@browser["howlong"]).perform
            @browser["howlong"].send_keys("9")
            @browser["submitter"].click
            wait = Selenium::WebDriver::Wait.new(:timeout => 20)
            wait.until { /Passphrase remembered for the next 9/.match(@browser.page_source) }
        end
    end

    describe "starts navigating" do
        it "opens navigation screen" do
            @browser.find_element(xpath: "//span[@id='navigate_menu']/a").click
        end

        it "opens navigation: demo/" do
            @browser.find_element(xpath: "//a[contains(@href,'/navigate/#{@config["username"]}/demo')]").click
        end

        it "opens navigation: demo/sub/" do
            @browser.find_element(xpath: "//a[contains(@href,'/navigate/#{@config["username"]}/demo%2Fsub')]").click
        end

        it "opens navigation: demo/sub/sub2" do
            @browser.find_element(xpath: "//a[contains(@href,'/navigate/#{@config["username"]}/demo%2Fsub%2Fsub2')]").click
        end

        it "opens navigation: demo/sub/sub2/sub3" do
            @browser.find_element(xpath: "//a[contains(@href,'/navigate/#{@config["username"]}/demo%2Fsub%2Fsub2%2Fsub3')]").click
        end

        it "navigates back up to sub" do
            @browser.find_element(xpath: "//a[contains(@href,'/navigate/#{@config["username"]}/demo%2Fsub%2Fsub2')]").click
            @browser.find_element(xpath: "//a[contains(@href,'/navigate/#{@config["username"]}/demo%2Fsub')]").click
            @browser.find_element(xpath: "//a[contains(@href,'/navigate/#{@config["username"]}/demo%2Fsub%2Fsub2')]")
            @browser.find_element(xpath: "//tr/th[normalize-space(text()) = 'demo/sub']")
        end
    end

    describe "manipulate files" do
        it "opens text file for viewing" do
            # do nothing: I am not storing my PGP key in the test browser...
        end

        it "opens new folder creation screen" do
            @browser.find_element(id: "newfolder")
            @browser["newfolder"].click
            @browser.find_element(id: "backbutton")
            @browser.find_element(id: "foldername")
            @browser.find_element(id: "submitter")
        end

        it "abandons folder creation" do
            @browser["backbutton"].click
            @browser.find_element(xpath: "//a[contains(@href,'/navigate/#{@config["username"]}/demo%2Fsub%2Fsub2')]")
            @browser.find_element(xpath: "//tr/th[normalize-space(text()) = 'demo/sub']")
        end
    end
end

