_ = require "underscore"
expect = require('chai').expect
ChildProcess = require './ChildProcess'
EventEmitter = require('events').EventEmitter
path = require 'path'
webdriverio = require 'webdriverio'
url = require 'url'

DEFAULT_PATH = process.env.PATH

SELENIUM_REMOTE_URL = url.parse(process.env.SELENIUM_REMOTE_URL)
SELENIUM_HOSTNAME = SELENIUM_REMOTE_URL.hostname
SELENIUM_PORT = SELENIUM_REMOTE_URL.port
SELENIUM_PATH = SELENIUM_REMOTE_URL.path

class Phantomjs extends EventEmitter

  browser: null
  intervals: null

  run: (url, options = '--load-images=no --ssl-protocol=TLSv1', script = "phantomjs-test-in-console.js", pipeClass = undefined, pipeClassOptions = undefined, useSystemPhantomjs = false)=>
    log.debug "Phantomjs.run()", arguments
    expect(@browser,"Browser is already connected").to.be.null
    expect(@intervals,"Polling interval is already running").to.be.null

    @intervals = []

    @browser = webdriverio.remote
      host: SELENIUM_HOSTNAME
      port: SELENIUM_PORT
      path: SELENIUM_PATH
      desiredCapabilities:
          browserName: "chrome"

    @browser
      .init()
      .url(url)

    # watch logs
    logInterval = setInterval () =>
      @browser
        .log("browser")
        .then (result) =>
          result.value.forEach (entry) =>
            if entry.message
              # sometimes console-runner emit enourmous and useless blobs
              # of json
              if (entry.message[0] == '{') && entry.message.match(/"url":"http:\/\/localhost:\d+\/packages\/practicalmeteor_mocha-console-runner\.js/)
                return

              # clean up really long console runner preamble
              message = entry.message.replace(/https?:\/\/localhost(:\d+)?\/packages\/([a-zA-Z0-9\-_]+)\.js(\?hash=\w+)?/, '[$2]')

              console.log(message)
    , 500
    @intervals.push(logInterval)

    # watch for completion
    completionInterval = setInterval () =>
      @browser
        .execute () =>
          result =
            done: false
            TEST_STATUS: window.TEST_STATUS
            DONE: window.DONE
            FAILURES: window.FAILURES
          if (typeof TEST_STATUS != "undefined") && (TEST_STATUS != null)
            result.done = TEST_STATUS.DONE;

          if (typeof DONE != "undefined") && (DONE != null)
            result.done = DONE;


          if result.done
            failures = false
            if (typeof TEST_STATUS != "undefined") && (TEST_STATUS != null)
              failures = TEST_STATUS.FAILURES;

            if (typeof FAILURES != "undefined") && (FAILURES != null)
              failures = FAILURES;


            result.code = if failures
              2
            else
              0

          result

        .then (response) =>
          result = response.value
          if result.done
            console.log("Got completion result", result)
            @kill()
            @emit "exit", result.code, ''
          else
            console.log("No completion result yet", result)
    , 500
    @intervals.push(completionInterval)


  kill: (signal = "SIGTERM")=>
    log.debug "Phantomjs.kill()"
    @intervals.forEach (interval) =>
      clearInterval(interval)


module.exports = Phantomjs

