export class Service extends EventTarget {
	logName = "Service";
	logColor = "rebeccapurple";

	log(...args: unknown[]): void {
		console.log(
			`%c${this.constructor.name}:`,
			`color: ${this.logColor}; font-weight: bold;`,
			...args,
		);
	}
}
