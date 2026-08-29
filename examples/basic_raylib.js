console.log("Starting Raylib...");

setTimeout(() => {
	InitWindow(800, 600, "Hello from JS");

	main_loop();
}, 0);

function main_loop() {
	if (WindowShouldClose()) return;

	console.log("hi...")
	setTimeout(main_loop, 1000)
}
