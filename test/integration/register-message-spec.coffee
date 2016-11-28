request       = require 'request'
mongojs       = require 'mongojs'
enableDestroy = require 'server-destroy'
shmock        = require 'shmock'
moment        = require 'moment'
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
      mongodbUri: 'interval-service-test'
      intervalServiceUri: 'http://interval-service.octoblu.test'

    @server = new Server serverOptions

    @server.run =>
      @serverPort = @server.address().port
      done()

  beforeEach (done) ->
    @db = mongojs 'interval-service-test', ['soldiers']
    @db.soldiers.remove done
    @datastore = @db.soldiers

  afterEach (done) ->
    @meshblu.destroy()
    @server.stop done

  context 'On POST /message', ->
    describe 'with topic of register-interval', ->
      describe 'when fireOnce is not set', ->
        beforeEach (done) ->
          record =
            metadata:
              ownerUuid: 'some-flow-uuid'
              nodeId: 'some-interval-node'
              intervalUuid: 'interval-device-uuid'
              credentialsOnly: true
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
              topic: 'register-interval'
              payload:
                nodeId: 'some-interval-node'
                sendTo: 'some-flow-uuid'
                nonce: 'this-is-nonce-ence'
                intervalTime: 10000

          request.post options, (error, @response, @body) =>
            @processAt = moment().unix()
            done error

        it 'should return a 201', ->
          expect(@response.statusCode).to.equal 201

        it 'should auth handler', ->
          @authDevice.done()

        it 'should save the job data to mongo', (done) ->
          query =
            'metadata.ownerUuid': 'some-flow-uuid'
            'metadata.nodeId': 'some-interval-node'
            'metadata.credentialsOnly': false
          @datastore.findOne query, {_id: false}, (error, record) =>
            return done error if error?
            expectedRecord =
              metadata:
                ownerUuid: 'some-flow-uuid'
                nodeId: 'some-interval-node'
                intervalUuid: 'interval-device-uuid'
                intervalTime: 10000
                nonce: 'this-is-nonce-ence'
                processAt: @processAt
                processNow: true
                fireOnce: false
                credentialsOnly: false
              data:
                fireOnce: false
                uuid: 'interval-device-uuid'
                token: 'interval-device-token'
                nodeId: 'some-interval-node'
                sendTo: 'some-flow-uuid'
            expect(record).to.deep.equal expectedRecord
            done()

    describe 'with topic of register-cron', ->
      beforeEach (done) ->
        record =
          metadata:
            ownerUuid: 'some-flow-uuid'
            nodeId: 'some-cron-node'
            credentialsOnly: true
            intervalUuid: 'interval-device-uuid'
          data:
            uuid: 'interval-device-uuid'
            token: 'interval-device-token'
            nodeId: 'some-cron-node'
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
            topic: 'register-cron'
            payload:
              nodeId: 'some-cron-node'
              sendTo: 'some-flow-uuid'
              cronString: 'some-cron-string'

        request.post options, (error, @response, @body) =>
          @processAt = moment().unix()
          done error

      it 'should return a 201', ->
        expect(@response.statusCode).to.equal 201

      it 'should auth handler', ->
        @authDevice.done()

      it 'should save the job data to mongo', (done) ->
        query =
          'metadata.ownerUuid': 'some-flow-uuid'
          'metadata.nodeId': 'some-cron-node'
          'metadata.credentialsOnly': false
        @datastore.findOne query, {_id: false}, (error, record) =>
          return done error if error?
          expectedRecord =
            metadata:
              ownerUuid: 'some-flow-uuid'
              nodeId: 'some-cron-node'
              intervalUuid: 'interval-device-uuid'
              cronString: 'some-cron-string'
              processAt: @processAt
              processNow: true
              fireOnce: false
              credentialsOnly: false
            data:
              uuid: 'interval-device-uuid'
              token: 'interval-device-token'
              nodeId: 'some-cron-node'
              sendTo: 'some-flow-uuid'
              fireOnce: false
          expect(record).to.deep.equal expectedRecord
          done()
