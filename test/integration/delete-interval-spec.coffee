http          = require 'http'
mongojs       = require 'mongojs'
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
      redisUri: 'redis://localhost'
      intervalServiceUri: 'http://interval-service.octoblu.test'

    @server = new Server serverOptions

    @server.run =>
      @serverPort = @server.address().port
      done()

  afterEach ->
    @meshblu.destroy()
    @server.destroy()

  beforeEach (done) ->
    @db = mongojs 'localhost', ['intervals']
    @db.intervals.remove done
    @datastore = @db.intervals

  describe 'On DELETE /nodes/:nodeId/destroy/:id', ->
    beforeEach (done) ->
      data =
        ownerId: 'some-uuid'
        nodeId: 'node-uuid'
      @datastore.insert data, done

    beforeEach (done) ->
      userAuth = new Buffer('some-uuid:some-token').toString 'base64'

      @authDevice = @meshblu
        .post '/authenticate'
        .set 'Authorization', "Basic #{userAuth}"
        .reply 200, uuid: 'some-uuid', token: 'some-token'

      @deleteDevice = @meshblu
        .delete '/devices/interval-uuid'
        .set 'Authorization', "Basic #{userAuth}"
        .reply 201

      options =
        uri: '/nodes/node-uuid/intervals/interval-uuid'
        baseUrl: "http://localhost:#{@serverPort}"
        auth:
          username: 'some-uuid'
          password: 'some-token'
        json:
          nodeId: 'node-uuid'

      request.delete options, (error, @response, @body) =>
        done error

    it 'should return a 200', ->
      expect(@response.statusCode).to.equal 200

    it 'should auth handler', ->
      @authDevice.done()

    it 'should delete the device', ->
      @deleteDevice.done()

    it 'should remove the mongodb entry', (done) ->
      @datastore.findOne id: 'interval-uuid', (error, record) =>
        return done error if error?
        expect(record).not.to.exist
        done()
