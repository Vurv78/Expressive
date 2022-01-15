local TOKEN = Syper.TOKEN

return {
	main = {
		{"(\n)", TOKEN.Other},
		{"([^\n]+)", TOKEN.Other},
	}
}