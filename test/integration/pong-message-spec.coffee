http          = require 'http'
request       = require 'request'
enableDestroy = require 'server-destroy'
shmock        = require '@octoblu/shmock'
Server        = require '../../src/server'
redis         = require 'redis'

describe 'Pong Message', ->
  before  (done) ->
    @client = redis.createClient()
    @client.on 'ready', done

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
      redisUri: 'redis://localhost'
      intervalServiceUri: 'http://interval-service.octoblu.test'

    @server = new Server serverOptions

    @server.run =>
      @serverPort = @server.address().port
      done()

  afterEach (done) ->
    @client.flushall done

  afterEach ->
    @meshblu.destroy()
    @server.destroy()

  describe 'On POST /message', ->
    beforeEach (done) ->
      userAuth = new Buffer('some-uuid:some-token').toString 'base64'

      @authDevice = @meshblu
        .post '/authenticate'
        .set 'Authorization', "Basic #{userAuth}"
        .reply 200, uuid: 'some-uuid', token: 'some-token'

      options =
        uri: '/message'
        baseUrl: "http://localhost:#{@serverPort}"
        auth:
          username: 'some-uuid'
          password: 'some-token'
        json: true
        body:
          topic: 'pong'

      request.post options, (error, @response, @body) =>
        done error

    it 'should return a 201', ->
      expect(@response.statusCode).to.equal 201

    it 'should auth handler', ->
      @authDevice.done()

    it 'should add one item in q:jobs', (done) ->
      @client.zlexcount '{q}:jobs', '-', '+', (error, length) =>
        expect(length).to.equal 1
        done error

    it 'should add one item in q:pong:jobs', (done) ->
      @client.llen '{q}:pong:jobs', (error, length) =>
        expect(length).to.equal 1
        done error

    it 'should have a job entry q:job:1', (done) ->
      @client.exists '{q}:job:1', (error, result) =>
        expect(result).to.equal 1
        done error

    it 'should not have a job entry q:job:2', (done) ->
      @client.exists '{q}:job:2', (error, result) =>
        expect(result).to.equal 0
        done error
