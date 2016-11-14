request       = require 'request'
mongojs       = require 'mongojs'
enableDestroy = require 'server-destroy'
shmock        = require 'shmock'
moment        = require 'moment'
Server        = require '../../src/server'

describe 'Legacy Fire Once Register Message', ->
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
      client: @fakeRedisClient
      publicKey:
        publicKey: null
      mongodbUri: 'interval-service-test'
      intervalServiceUri: 'http://interval-service.octoblu.test'

    @server = new Server serverOptions

    @server.run =>
      @serverPort = @server.address().port
      done()

  beforeEach ->
    @db = mongojs 'interval-service-test'
    @collection = @db.collection 'soldiers'
    @legacyCollection = @db.collection 'intervals'

  beforeEach (done) ->
    @collection.remove done

  beforeEach (done) ->
    @legacyCollection.remove done

  afterEach (done) ->
    @meshblu.destroy()
    @server.stop done

  context 'On POST /message', ->
    describe 'with data on legacy', ->
      beforeEach (done) ->
        record =
          ownerId: 'some-flow-uuid'
          nodeId: 'some-interval-node'
          id: 'interval-device-uuid'
          token: 'interval-device-token'
          data:
            intervalTime: 1000
            nodeId: 'some-interval-node'
        @legacyCollection.insert record, done

      beforeEach (done) ->
        userAuth = new Buffer('some-uuid:some-token').toString 'base64'

        @authDevice = @meshblu
          .post '/authenticate'
          .set 'Authorization', "Basic #{userAuth}"
          .reply 200, uuid: 'some-uuid', token: 'some-token'

        @fakeRedisClient.del.yields null
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
              transactionId: 'some-transaction-id'
              sendTo: 'some-flow-uuid'
              nonce: 'this-is-nonce-ence'
              intervalTime: 10000
              fireOnce: true

        request.post options, (error, @response, @body) =>
          @processAt = moment().unix()
          done error

      it 'should return a 201', ->
        expect(@response.statusCode).to.equal 201

      it 'should auth handler', ->
        @authDevice.done()

      it 'should deactivate any old intervals', ->
        expect(@fakeRedisClient.del).to.have.been.calledWith 'interval/active/some-flow-uuid/some-transaction-id'

      it 'should save the job data to mongo', (done) ->
        query =
          'metadata.ownerUuid'    : 'some-flow-uuid'
          'metadata.transactionId': 'some-transaction-id'
        @collection.findOne query, {_id: false}, (error, record) =>
          return done error if error?
          expectedRecord =
            metadata:
              ownerUuid: 'some-flow-uuid'
              transactionId: 'some-transaction-id'
              intervalUuid: 'interval-device-uuid'
              intervalTime: 10000
              nonce: 'this-is-nonce-ence'
              processAt: @processAt
              processNow: true
              fireOnce: true
            data:
              fireOnce: true
              uuid: 'interval-device-uuid'
              token: 'interval-device-token'
              nodeId: 'some-interval-node'
              transactionId: 'some-transaction-id'
              sendTo: 'some-flow-uuid'
          expect(record).to.deep.equal expectedRecord
          done()

    describe 'with data on legacy', ->
      beforeEach (done) ->
        record =
          ownerId: 'some-flow-uuid'
          nodeId: 'some-interval-node'
          id: 'interval-device-uuid'
          token: 'interval-device-token'
        @legacyCollection.insert record, done

      beforeEach (done) ->
        userAuth = new Buffer('some-uuid:some-token').toString 'base64'

        @authDevice = @meshblu
          .post '/authenticate'
          .set 'Authorization', "Basic #{userAuth}"
          .reply 200, uuid: 'some-uuid', token: 'some-token'

        @fakeRedisClient.del.yields null
        
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
              transactionId: 'some-transaction-id'
              sendTo: 'some-flow-uuid'
              nonce: 'this-is-nonce-ence'
              intervalTime: 10000
              fireOnce: true

        request.post options, (error, @response, @body) =>
          @processAt = moment().unix()
          done error

      it 'should return a 201', ->
        expect(@response.statusCode).to.equal 201

      it 'should auth handler', ->
        @authDevice.done()

      it 'should deactivate any old intervals', ->
        expect(@fakeRedisClient.del).to.have.been.calledWith 'interval/active/some-flow-uuid/some-transaction-id'

      it 'should save the job data to mongo', (done) ->
        query =
          'metadata.ownerUuid'    : 'some-flow-uuid'
          'metadata.transactionId': 'some-transaction-id'
        @collection.findOne query, {_id: false}, (error, record) =>
          return done error if error?
          expectedRecord =
            metadata:
              ownerUuid: 'some-flow-uuid'
              transactionId: 'some-transaction-id'
              intervalUuid: 'interval-device-uuid'
              intervalTime: 10000
              nonce: 'this-is-nonce-ence'
              processAt: @processAt
              processNow: true
              fireOnce: true
            data:
              fireOnce: true
              uuid: 'interval-device-uuid'
              token: 'interval-device-token'
              nodeId: 'some-interval-node'
              transactionId: 'some-transaction-id'
              sendTo: 'some-flow-uuid'
          expect(record).to.deep.equal expectedRecord
          done()
