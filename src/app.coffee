Promise = require 'bluebird'
fs = Promise.promisifyAll(require('fs'))
express = require 'express'
bodyParser = require 'body-parser'

config = require './config'

utils = require './utils'
connman = require './connman'
hotspot = require './hotspot'
wifiScan = require './wifi-scan'

app = express()

app.use(bodyParser.json())
app.use(bodyParser.urlencoded(extended: true))
app.use(express.static(__dirname + '/public'))

ssids = []

app.get '/ssids', (req, res) ->
	res.json(ssids)

attemptConnect = () ->
	fs.statAsync(config.persistentConfig)
	.then ->
		data = fs.readFile(config.persistentConfig,'utf8');
		Promise.all [
			utils.durableWriteFile(config.connmanConfig, data)
			hotspot.stop()
		]
	.delay(1000)	
	.then ->
		connman.waitForConnection(15000)
	.then ->
		process.exit()
	.catch (e) ->
		hotspot.start()

app.post '/connect', (req, res) ->
	if not (req.body.ssid? and req.body.passphrase?)
		return res.sendStatus(400)

	console.log('Selected ' + req.body.ssid)

	res.send('OK')

	data = """
		[service_home_ethernet]
		Type = ethernet
		Nameservers = 8.8.8.8,8.8.4.4

		[service_home_wifi]
		Type = wifi
		Name = #{req.body.ssid}
		Passphrase = #{req.body.passphrase}
		Nameservers = 8.8.8.8,8.8.4.4

	"""

	Promise.all [
		utils.durableWriteFile(config.connmanConfig, data)
		hotspot.stop()
	]
	# XXX: make it so this delay isn't needed
	.delay(1000)
	.then ->
		connman.waitForConnection(15000)
	.then ->
		utils.durableWriteFile(config.persistentConfig, data)
	.then ->
		process.exit()
	.catch (e) ->
		hotspot.start()

app.use (req, res) ->
	res.redirect('/')

wifiScan.scanAsync()
.then (results) ->
	ssids = results

	hotspot.start()

setTimeOut(attemptConnect,2*60*1000)
app.listen(9080)
