import { Maybe } from "@/utils/types";
import { Preferences } from "@capacitor/preferences";

export abstract class Service<const State = unknown> extends EventTarget {
	abstract logName: string;
	abstract logColor: string;

	log(...args: unknown[]): void {
		console.log(`%c${this.logName}:`, `color: ${this.logColor}; font-weight: bold;`, ...args);
	}

	get #taggedKey(): string {
		return `${this.logName}`;
	}

	async clearState(): Promise<void> {
		this.log("clearState");
		await Preferences.remove({ key: this.#taggedKey });
	}

	async saveState(data: State): Promise<void> {
		this.log("saveState");
		await Preferences.set({ key: this.#taggedKey, value: JSON.stringify(data) });
	}

	async getSavedState(): Promise<Maybe<State>> {
		this.log("getSavedState");
		const { value } = await Preferences.get({ key: this.#taggedKey });
		return value && JSON.parse(value);
	}
}
