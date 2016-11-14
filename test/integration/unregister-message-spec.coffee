request       = require 'request'
shmock        = require 'shmock'
enableDestroy = require 'server-destroy'
mongojs       = require 'mongojs'
Server        = require '../../src/server'

describe 'Unregister Message', ->
  beforeEach (done) ->
    @meshblu = shmock 0xd00d
    enableDestroy @meshblu

    @fakeRedisClient = {
      del: sinon.stub()
    }

    serverOptions =
      port: undefined,
      disableLogging: true
      meshbluConfig:
        hostname: 'localhost'
        port: 0xd00d
        protocol: 'http'
      publicKey:
        publicKey: null
      client: @fakeRedisClient
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

  afterEach ->
    @meshblu.destroy()
    @server.destroy()

  context 'On POST /message', ->
    describe 'with topic of unregister-interval', ->
      beforeEach (done) ->
        record =
          metadata:
            ownerUuid: 'some-flow-uuid'
            nodeId: 'some-interval-node'
            intervalUuid: 'interval-device-uuid'
          data:
            uuid: 'interval-device-uuid'
            token: 'interval-device-token'
            nodeId: 'some-interval-node'
        @datastore.insert record, done

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
            topic: 'unregister-interval'
            payload:
              nodeId: 'some-interval-node'
              sendTo: 'some-flow-uuid'

        request.post options, (error, @response, @body) =>
          done error
          
      it 'should return a 204', ->
        expect(@response.statusCode).to.equal 204

      it 'should auth handler', ->
        @authDevice.done()

      it 'should remove the job data to mongo', (done) ->
        query =
          'metadata.ownerUuid': 'some-flow-uuid'
          'metadata.nodeId': 'some-interval-node'
        @datastore.findOne query, {_id: false}, (error, record) =>
          return done error if error?
          expect(record).to.not.exist
          done()

    describe 'with topic of unregister-interval and it has a fireOnce', ->
      beforeEach (done) ->
        record =
          metadata:
            ownerUuid: 'some-flow-uuid'
            nodeId: 'some-interval-node'
            intervalUuid: 'interval-device-uuid'
          data:
            uuid: 'interval-device-uuid'
            token: 'interval-device-token'
            nodeId: 'some-interval-node'
        @datastore.insert record, done

      beforeEach (done) ->
        record =
          metadata:
            ownerUuid: 'some-flow-uuid'
            nodeId: 'some-interval-node'
            transactionId: 'some-transaction-id'
            intervalUuid: 'interval-device-uuid'
          data:
            uuid: 'interval-device-uuid'
            token: 'interval-device-token'
            nodeId: 'some-interval-node'
            transactionId: 'some-transaction-id'
        @datastore.insert record, done

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
            topic: 'unregister-interval'
            payload:
              nodeId: 'some-interval-node'
              transactionId: 'some-transaction-id'
              sendTo: 'some-flow-uuid'

        request.post options, (error, @response, @body) =>
          done error

      it 'should return a 204', ->
        expect(@response.statusCode).to.equal 204

      it 'should auth handler', ->
        @authDevice.done()

      it 'should remove the job data to mongo', (done) ->
        query =
          'metadata.ownerUuid': 'some-flow-uuid'
          'metadata.nodeId': 'some-interval-node'
        @datastore.findOne query, {_id: false}, (error, record) =>
          return done error if error?
          expect(record).to.not.exist
          done()

      it 'should remove the fireOnce job data to mongo', (done) ->
        query =
          'metadata.ownerUuid': 'some-flow-uuid'
          'metadata.transactionId': 'some-transaction-id'
        @datastore.findOne query, {_id: false}, (error, record) =>
          return done error if error?
          expect(record).to.not.exist
          done()

    describe 'with topic of unregister-cron', ->
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
            topic: 'unregister-cron'
            payload:
              nodeId: 'some-cron-node'
              sendTo: 'some-flow-uuid'

        request.post options, (error, @response, @body) =>
          done error

      it 'should return a 201', ->
        expect(@response.statusCode).to.equal 204

      it 'should auth handler', ->
        @authDevice.done()

      it 'should remove the job data to mongo', (done) ->
        query =
          'metadata.ownerUuid': 'some-flow-uuid'
          'metadata.nodeId': 'some-cron-node'
        @datastore.findOne query, {_id: false}, (error, record) =>
          return done error if error?
          expect(record).to.not.exist
          done()
