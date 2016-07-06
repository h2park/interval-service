http          = require 'http'
request       = require 'request'
enableDestroy = require 'server-destroy'
shmock        = require '@octoblu/shmock'
Server        = require '../../src/server'

describe 'Delete Interval', ->
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

  describe 'On DELETE /destroy', ->
    beforeEach (done) ->
      userAuth = new Buffer('some-uuid:some-token').toString 'base64'

      @authDevice = @meshblu
        .post '/authenticate'
        .set 'Authorization', "Basic #{userAuth}"
        .reply 200, uuid: 'some-uuid', token: 'some-token'

      @getDevices = @meshblu
        .get '/v2/devices'
        .set 'Authorization', "Basic #{userAuth}"
        .reply 201, [
          {uuid: 'device-uuid-1', token: 'device-token-1'}
          {uuid: 'device-uuid-2', token: 'device-token-2'}
        ]

      @deleteDevice1 = @meshblu
        .delete '/devices/device-uuid-1'
        .set 'Authorization', "Basic #{userAuth}"
        .reply 201

      @deleteDevice2 = @meshblu
        .delete '/devices/device-uuid-2'
        .set 'Authorization', "Basic #{userAuth}"
        .reply 201

      options =
        uri: '/intervals'
        baseUrl: "http://localhost:#{@serverPort}"
        auth:
          username: 'some-uuid'
          password: 'some-token'
        json: true

      request.delete options, (error, @response, @body) =>
        done error

    it 'should return a 200', ->
      expect(@response.statusCode).to.equal 200

    it 'should auth handler', ->
      @authDevice.done()

    it 'should get devices', ->
      @getDevices.done()

    it 'should delete the first device', ->
      @deleteDevice1.done()

    it 'should delete the second device', ->
      @deleteDevice2.done()
