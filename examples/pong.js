const paddle_width = 10;
const paddle_height = 50;
const paddle_offset = 25;
const paddle_speed = 2.5;

const divider_width = 10;

const ball_radius = 7;


const paddle1_x = paddle_offset;
var paddle1_y = window_height/2 - paddle_height/2;
var score1 = 0;
const paddle2_x = window_width - paddle_offset - paddle_width;
var paddle2_y = window_height/2 - paddle_height/2;
var score2 = 0;

var ball_x = window_width/2;
var ball_y = window_height/2;
var ball_dx = 2.5;
var ball_dy = 2.5;

var dx_idx = 0;
const dx_seq = [3.7, -3, -3, 2.6, 2.75, -3.35];
var dy_idx = 0;
const dy_seq = [3.7, -3.3, 3.3, -2.6, 3];

function DrawTextCentered(text, x_center, y, font_size, color) {
	const width = MeasureText(text, font_size);
	DrawText(text, x_center - width/2, y, font_size, color);
}

function respawn_ball() {
	dx_idx += 1;
	if (dx_idx == dx_seq.length) dx_idx = 0;
	dy_idx += 1;
	if (dy_idx == dy_seq.length) dy_idx = 0;

	ball_x = window_width/2;
	ball_y = window_height/2;
	ball_dx = dx_seq[dx_idx];
	ball_dy = dx_seq[dy_idx];
}

function collide_circle_rect(cx, cy, r, x, y, w, h) {
	// NOTE: Currently square-rect collision and not circle-rect

	const collide_x = (cx + r >= x && cx - r <= x + w) ||
	                  (cx - r <= x + w && cx + r >= x);

	const collide_y = (cy + r >= y && cy - r <= y + h) ||
	                  (cy - r <= y + h && cy + r >= y);
	return collide_x && collide_y;
}

function update() {
	ball_x += ball_dx;
	ball_y += ball_dy;

	if (IsKeyDown(Key.F)) {
		paddle1_y += paddle_speed;
		if (paddle1_y + paddle_height >= window_height) paddle1_y = window_height - paddle_height - 1;
	} else if (IsKeyDown(Key.D)) {
		paddle1_y -= paddle_speed;
		if (paddle1_y < 0) paddle1_y = 0;
	}

	if (IsKeyDown(Key.J)) {
		paddle2_y += paddle_speed;
		if (paddle2_y + paddle_height >= window_height) paddle2_y = window_height - paddle_height - 1;
	} else if (IsKeyDown(Key.K)) {
		paddle2_y -= paddle_speed;
		if (paddle2_y < 0) paddle2_y = 0;
	}

	if (ball_x + ball_radius >= window_width) {
		score1 += 1;
		window_title = "Pong: " + score1 + " -- " + score2;
		respawn_ball();

		return
	} else if (ball_x - ball_radius < 0) {
		score2 += 1;
		window_title = "Pong: " + score1 + " -- " + score2;
		respawn_ball();

		return
	}

	if (ball_y + ball_radius >= window_height) {
		ball_dy = -ball_dy;
		ball_y = window_height - ball_radius - 1;
	} else if (ball_y - ball_radius < 0) {
		ball_dy = -ball_dy;
		ball_y = ball_radius;
	}

	if (collide_circle_rect(ball_x, ball_y, ball_radius, paddle1_x, paddle1_y, paddle_width, paddle_height)) {
		ball_dx = -ball_dx;
		ball_x = paddle1_x+paddle_width+ball_radius;
	} else if (collide_circle_rect(ball_x, ball_y, ball_radius, paddle2_x, paddle2_y, paddle_width, paddle_height)) {
		ball_dx = -ball_dx;
		ball_x = paddle2_x-ball_radius;
	}
}

function draw() {
	const centre_x = window_width / 2;
	const centre_y = window_height / 2;

	ClearBackground(Color.RAYWHITE);

	DrawRectangle(centre_x - divider_width/2, 0, divider_width, window_height, Color.DARKGRAY);

	DrawRectangle(paddle1_x, paddle1_y, paddle_width, paddle_height, Color.BLACK);
	DrawRectangle(paddle2_x, paddle2_y, paddle_width, paddle_height, Color.BLACK);

	const half_window_width = (window_width - divider_width)/2;
	DrawTextCentered(""+score1, half_window_width/2, 20, 50, Color.BLACK);
	DrawTextCentered(""+score2, window_width - half_window_width/2, 20, 50, Color.BLACK);

	DrawFPS(10, 10)

	DrawCircle(ball_x, ball_y, ball_radius, Color.BLACK);
}

window_title = "Pong";
