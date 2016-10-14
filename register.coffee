_ = require 'lodash'
async = require 'async'
kue = require 'kue'
mongojs = require 'mongojs'
Redis   = require 'ioredis'

queue = kue.createQueue
  redis:
    createClientFactory: =>
      new Redis process.env.REDIS_URI, dropBufferSupport: true

client = new Redis process.env.REDIS_URI, dropBufferSupport: true
client.on 'ready', =>
  client.flushall =>
    database = mongojs process.env.MONGODB_URI, ['intervals']
    datastore = database.intervals

    register = (record, callback) =>
      return callback() if record.data.fireOnce
      return callback() unless record.token?
      queue.create('register', record.data)
        .events(false)
        .removeOnComplete(true)
        .ttl(5000)
        .save (error) =>
          callback error

    datastore.find {}, (error, records) =>
      async.eachSeries records, register, (error) =>
        console.log {error}
        process.exit 0
