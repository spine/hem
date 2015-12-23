#--------- Hem setup options

defaultHem =
	baseAppRoute: "/"
	tests:
		runner: "browser"

proxyHem =
	baseAppRoute: "/"
	tests:
		runner: "browser"
	proxy:
		"/proxy":
			"host": "www.yoursite.com"
			"path": "/proxy"

#--------- main configuration setup

config =

	# main hem configuration
	hem: defaultHem

	# appliation configuration

	application:
		defaults: "spine"
		js:
			libs: [
				'lib/jquery.js',
				'lib/jade_runtime.js'
			]
			modules: [
				"spine",
				"spine/lib/ajax",
				"spine/lib/route",
				"spine/lib/manager",
				"spine/lib/local"
			]
		test:
			after: "require('lib/setup')"

#--------- export the configuration map for hem

module.exports.config = config

#--------- customize hem

module.exports.customize = (hem) ->
	# provide hook to customize the hem instance,
	# called after config is parsed/processed.
	return
