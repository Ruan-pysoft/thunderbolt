setTimeout(() => {
	console.log("A");

	Promise.resolve().then(() => console.log("A+"));
}, 0);

setTimeout(() => {
	console.log("B");
}, 5);

console.log("sync");
