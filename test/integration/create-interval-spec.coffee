http          = require 'http'
request       = require 'request'
enableDestroy = require 'server-destroy'
shmock        = require '@octoblu/shmock'
Server        = require '../../src/server'

describe 'Create Interval', ->
  beforeEach (done) ->
    @meshblu = shmock 0xd00d
    enableDestroy @meshblu

    serverOptions =
      port: undefined,
      disableLogging: true
      meshbluConfig:
        hostname: 'localhost'
        port: 0xd00d
        protocol: 'http'
      mongodbUri: 'localhost'

    @server = new Server serverOptions

    @server.run =>
      @serverPort = @server.address().port
      done()

  afterEach ->
    @meshblu.destroy()
    @server.destroy()

  describe 'On POST /intervals', ->
    beforeEach (done) ->
      userAuth = new Buffer('some-uuid:some-token').toString 'base64'

      @authDevice = @meshblu
        .post '/authenticate'
        .set 'Authorization', "Basic #{userAuth}"
        .reply 200, uuid: 'some-uuid', token: 'some-token'

      @registerDevice = @meshblu
        .post '/devices'
        .set 'Authorization', "Basic #{userAuth}"
        .reply 201, uuid: 'interval-uuid', token: 'interval-token'

      options =
        uri: '/intervals'
        baseUrl: "http://localhost:#{@serverPort}"
        auth:
          username: 'some-uuid'
          password: 'some-token'
        json: true

      request.post options, (error, @response, @body) =>
        done error

    it 'should return a 200', ->
      expect(@response.statusCode).to.equal 200

    it 'should auth handler', ->
      @authDevice.done()

    it 'should register handler', ->
      @registerDevice.done()

    it 'should send back a uuid', ->
      expect(@body.uuid).to.equal 'interval-uuid'

  # describe 'when the service yields an error', ->
  #   beforeEach (done) ->
  #     userAuth = new Buffer('some-uuid:some-token').toString 'base64'
  #
  #     @authDevice = @meshblu
  #       .post '/authenticate'
  #       .set 'Authorization', "Basic #{userAuth}"
  #       .reply 200, uuid: 'some-uuid', token: 'some-token'
  #
  #     options =
  #       uri: '/intervals'
  #       baseUrl: "http://localhost:#{@serverPort}"
  #       auth:
  #         username: 'some-uuid'
  #         password: 'some-token'
  #       qs:
  #         hasError: true
  #       json: true
  #
  #     request.post options, (error, @response, @body) =>
  #       done error
  #
  #   it 'should auth and response with 755', ->
  #     expect(@response.statusCode).to.equal 755
  #     @authDevice.done()