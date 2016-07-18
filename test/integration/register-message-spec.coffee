http          = require 'http'
request       = require 'request'
mongojs       = require 'mongojs'
enableDestroy = require 'server-destroy'
shmock        = require '@octoblu/shmock'
Server        = require '../../src/server'
redis         = require 'redis'

describe 'Register Message', ->
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

  beforeEach (done) ->
    @db = mongojs 'localhost', ['intervals']
    @db.intervals.remove done
    @datastore = @db.intervals

  afterEach (done) ->
    @client.flushall done

  afterEach (done) ->
    @meshblu.destroy()
    @server.stop done

  context 'On POST /message', ->
    describe 'with topic of register-interval', ->
      beforeEach (done) ->
        data =
          ownerId: 'some-flow-uuid'
          nodeId: 'some-interval-node'
          id: 'interval-device-uuid'
          token: 'interval-device-token'

        @datastore.insert data, done

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
            topic: 'register-interval'
            payload:
              nodeId: 'some-interval-node'
              sendTo: 'some-flow-uuid'
              nonce: 'this-is-nonce-ence'

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

      it 'should add one item in q:register:jobs', (done) ->
        @client.llen '{q}:register:jobs', (error, length) =>
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

      it 'should set interval/uuid/:flowId/:nodeId', (done) ->
        @client.get 'interval/uuid/some-flow-uuid/some-interval-node', (error, uuid) =>
          expect(uuid).to.equal 'interval-device-uuid'
          done error

      it 'should set interval/token/:flowId/:nodeId', (done) ->
        @client.get 'interval/token/some-flow-uuid/some-interval-node', (error, token) =>
          expect(token).to.equal 'interval-device-token'
          done error

      it 'should save the job data to mongo', (done) ->
        @datastore.findOne {ownerId: 'some-flow-uuid', nodeId: 'some-interval-node'}, (error, record) =>
          return done error if error?
          data =
            nodeId: 'some-interval-node'
            sendTo: 'some-flow-uuid'
            nonce: 'this-is-nonce-ence'
          expect(record.data).to.deep.equal data
          done()

    describe 'with topic of register-cron', ->
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
            topic: 'register-cron'
            payload:
              nodeId: 'some-cron-node'
              sendTo: 'some-flow-uuid'

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

      it 'should add one item in q:register:jobs', (done) ->
        @client.llen '{q}:register:jobs', (error, length) =>
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
