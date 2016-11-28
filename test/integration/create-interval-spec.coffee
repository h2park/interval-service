http          = require 'http'
request       = require 'request'
mongojs       = require 'mongojs'
enableDestroy = require 'server-destroy'
shmock        = require 'shmock'
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
        uuid: 'the-interval-service-uuid'
        token: 'the-interval-service-token'
      mongodbUri: 'interval-service-test'
      client: {}
      publicKey:
        publicKey: null
      intervalServiceUri: 'http://interval-service.octoblu.test'

    @server = new Server serverOptions

    @server.run =>
      @serverPort = @server.address().port
      done()

  afterEach (done) ->
    @meshblu.destroy()
    @server.stop done

  beforeEach (done) ->
    @db = mongojs 'interval-service-test', ['soldiers']
    @db.soldiers.remove done
    @datastore = @db.soldiers

  describe 'On POST /nodes/:nodeId/intervals', ->
    beforeEach (done) ->
      userAuth = new Buffer('some-uuid:some-token').toString 'base64'
      intervalAuth = new Buffer('interval-uuid:interval-token').toString 'base64'

      @authDevice = @meshblu
        .post '/authenticate'
        .set 'Authorization', "Basic #{userAuth}"
        .reply 200, uuid: 'some-uuid', token: 'some-token'

      @registerDevice = @meshblu
        .post '/devices'
        .set 'Authorization', "Basic #{userAuth}"
        .reply 201, uuid: 'interval-uuid', token: 'interval-token'

      @subscribeDevice = @meshblu
        .post '/v2/devices/interval-uuid/subscriptions/interval-uuid/message.received'
        .set 'Authorization', "Basic #{intervalAuth}"
        .reply 204

      options =
        uri: '/nodes/node-uuid/intervals'
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

    it 'should subscribe handler', ->
      @subscribeDevice.done()

    it 'should send back a uuid', ->
      expect(@body.uuid).to.equal 'interval-uuid'

    it 'should create the record in mongo', (done) ->
      query =
        'metadata.ownerUuid' : 'some-uuid'
        'metadata.nodeId': 'node-uuid'
      @datastore.findOne query, {_id: false}, (error, record) =>
        return done error if error?
        expect(record).to.deep.equal
          data:
            nodeId: 'node-uuid'
            uuid: 'interval-uuid'
            token: 'interval-token'
          metadata:
            nodeId: 'node-uuid'
            intervalUuid: 'interval-uuid'
            ownerUuid: 'some-uuid'
            credentialsOnly: true
        done()
