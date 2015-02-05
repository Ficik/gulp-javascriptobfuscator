"use strict"

http = require "http"

unescapeHTML = (str) ->
	return ""	unless str?
	escapeChars =
		lt: '<',
		gt: '>',
		quot: '"',
		apos: "'",
		amp: '&'
	String(str).replace /\&([^;]+);/g, (entity, entityCode) ->
		match = undefined
		if entityCode of escapeChars
			escapeChars[entityCode]
		else if match = entityCode.match(/^#x([\da-fA-F]+)$/)
			String.fromCharCode parseInt(match[1], 16)
		else if match = entityCode.match(/^#(\d+)$/)
			String.fromCharCode ~~match[1]
		else
			entity

obfuscate = (source, options, cb) ->
	options = {} unless options
	for item in ["encodeString", "encodeNumber", "replaceNames", "moveString"]
		unless options[item]? then options[item] = "on"
		else options[item] = if (!!options[item]) then "on" else "off"
	options.exclusions = ["^_get_", "^_set_", "^_mtd_"] unless options.exclusions?
	site = "www.javascriptobfuscator.com"
	req = http.get
		hostname: site,
		port: 80,
		path: "/Javascript-Obfuscator.aspx"
	, (res) ->
		res.setEncoding "utf8"
		data = ""
		res.on "data", (chunk) ->
			data += chunk
		res.on "end", ->
			viewState = ///id=\"__VIEWSTATE\".+value=\"(.+)\"///.exec(data)[1]
			viewStateGenerator = ///id=\"__VIEWSTATEGENERATOR\".+value=\"(.+)\"///.exec(data)[1]
			eventValidation = ///id=\"__EVENTVALIDATION\".+value=\"(.+)\"///.exec(data)[1]
			qr = require "querystring"
			.stringify
				UploadLib_Uploader_js:1,
				"ctl00$breadcrumbs$uploader1":"",
				__VIEWSTATE: viewState,
				__VIEWSTATEGENERATOR: viewStateGenerator,
				__EVENTTARGET:"ctl00$breadcrumbs$Button1",
				__EVENTARGUMENT:"",
				__EVENTVALIDATION: eventValidation,
				"ctl00$breadcrumbs$TextBox1": source,
				"ctl00$MainContent$cbEncodeStr": options.encodeString,
				"ctl00$MainContent$cbEncodeNumber": options.encodeNumber,
				"ctl00$MainContent$cbMoveStr": options.replaceNames,
				"ctl00$MainContent$cbReplaceNames": options.moveString,
				TextBox3: options.exclusions.join "\r\n"
			req2 = http.request
				hostname: site,
				port: 80,
				path: "/Javascript-Obfuscator.aspx",
				method: "POST"
				headers:
					'Content-Type': 'application/x-www-form-urlencoded'
			, (res) ->
				res.setEncoding "utf8"
				data = ""
				res.on "data", (chunk) -> data += chunk
				res.on "end", ->
					try
						code = ///<textarea([^>]+)>\r\n(.+)</textarea>///.exec data
						cb? null, unescapeHTML code[2]
					catch ex
						cb? ex
			req2.on "error", (error) -> cb? error
			req2.write qr
			req2.end()
	req.on "error", (error) -> cb? error
	req.end()

module.exports = (options) ->
	require "through2"
	.obj (file, encoding, callback) ->
		if file.isNull()
			@push file
			return callback()
		return callback new Error("gulp-jsobfuscator: Streaming not supported") if file.isStream()
		obfuscate file.contents.toString(encoding), options, (error, data) =>
			return callback error if error?
			file.contents = new Buffer data
			@push file
			callback()

module.exports.obfuscate = obfuscate
