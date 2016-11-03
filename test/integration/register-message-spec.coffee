request       = require 'request'
mongojs       = require 'mongojs'
enableDestroy = require 'server-destroy'
shmock        = require 'shmock'
Server        = require '../../src/server'

describe 'Register Message', ->
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
      publicKey:
        publicKey: null
      mongodbUri: 'localhost'
      intervalServiceUri: 'http://interval-service.octoblu.test'

    @server = new Server serverOptions

    @server.run =>
      @serverPort = @server.address().port
      done()

  beforeEach (done) ->
    @db = mongojs 'localhost', ['soldiers']
    @db.soldiers.remove done
    @datastore = @db.soldiers

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
