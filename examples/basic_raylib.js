var rect_x = null;
var rect_y = null;
var rect_xy_vel = 2.5;
var rect_dx = rect_xy_vel;
var rect_dy = rect_xy_vel;
const rect_size = 42;

function update() {
	if (rect_x === null) {
		rect_x = window_width/2 - rect_size/2;
	} else {
		rect_x += rect_dx;
		if (rect_x + rect_size >= window_width) {
			rect_dx = -rect_xy_vel;
			rect_x = window_width-1 - rect_size;

			var temp = rect_color;
			rect_color = bg_color;
			bg_color = temp;
		} else if (rect_x < 0) {
			rect_dx = rect_xy_vel;
			rect_x = 0;

			var temp = rect_color;
			rect_color = bg_color;
			bg_color = temp;
		}
	}

	if (rect_y === null) {
		rect_y = window_height/2 - rect_size/2;
	} else {
		rect_y += rect_dy;
		if (rect_y + rect_size >= window_height) {
			rect_dy = -rect_xy_vel;
			rect_y = window_height-1 - rect_size;

			var temp = rect_color;
			rect_color = bg_color;
			bg_color = temp;
		} else if (rect_y < 0) {
			rect_dy = rect_xy_vel;
			rect_y = 0;

			var temp = rect_color;
			rect_color = bg_color;
			bg_color = temp;
		}
	}
}

function draw() {
	ClearBackground(bg_color.r, bg_color.g, bg_color.b)

	DrawRectangle(rect_x, rect_y, rect_size, rect_size, rect_color.r, rect_color.g, rect_color.b)
}

var window_title = "Hello from JS!";
var window_width = 640;
var window_height = 480;

var bg_color = new Color(20, 50, 100)
var rect_color = new Color(200, 15, 15)
console.log("bg_color:", bg_color)
console.log("rect_color:", rect_color)
console.log("bg_color:", Object.prototype.toString.call(bg_color))
