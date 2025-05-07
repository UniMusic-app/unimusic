export function secondsToMMSS(time: number): string {
	const minutes = String(Math.floor(time / 60)).padStart(2, "0");
	const seconds = String(Math.floor(time % 60)).padStart(2, "0");
	return `${minutes}:${seconds}`;
}

export async function sleep(millis: number): Promise<void> {
	await new Promise((r) => setTimeout(r, millis));
}
