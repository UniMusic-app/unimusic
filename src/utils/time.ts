export function secondsToMMSS(time: number): string {
	const minutes = String(Math.round(time / 60)).padStart(2, "0");
	const seconds = String(Math.round(time % 60)).padStart(2, "0");
	return `${minutes}:${seconds}`;
}
