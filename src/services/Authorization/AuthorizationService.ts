import { Service } from "@/services/Service";
import { Maybe } from "@/utils/types";
import { Preferences } from "@capacitor/preferences";

export class AuthorizedEvent<Data> extends CustomEvent<Data> {
	constructor(data: Data) {
		super("authorized", { detail: data });
	}
}

export class UnauthorizedEvent extends CustomEvent<never> {
	constructor() {
		super("unauthorized");
	}
}

export abstract class AuthorizationService<const Data = unknown> extends Service {
	logName = "AuthorizationService";
	logColor = "#3040ff";

	abstract key: string;
	isAuthorized = false;

	get #taggedKey(): string {
		return `Auth-${this.key}`;
	}

	constructor() {
		super();

		this.addEventListener("authorized", () => (this.isAuthorized = true));
		this.addEventListener("unauthorized", () => (this.isAuthorized = false));
	}

	addEventListener(
		type: "authorized" | "unauthorized",
		callback: EventListenerOrEventListenerObject | null,
		options?: AddEventListenerOptions | boolean,
	): void {
		super.addEventListener(type, callback, options);
	}

	emitAuthorized(data: Data): boolean {
		return this.dispatchEvent(new AuthorizedEvent(data));
	}
	emitUnauthorized(): boolean {
		return this.dispatchEvent(new UnauthorizedEvent());
	}
	emitAppropriate(data?: Maybe<Data>): boolean {
		if (data) return this.emitAuthorized(data);
		return this.emitUnauthorized();
	}

	abstract handlePassivelyAuthorize(): Promise<Maybe<Data>> | Maybe<Data>;
	async passivelyAuthorize(): Promise<Maybe<Data>> {
		this.log("passivelyAuthorize");
		return await this.handlePassivelyAuthorize();
	}

	abstract handleAuthorize(): Promise<Data> | Data;
	async authorize(): Promise<Data> {
		this.log("authorize");
		const data = await this.handleAuthorize();
		this.emitAuthorized(data);
		return data;
	}

	abstract handleUnauthorize(): Promise<void> | void;
	async unauthorize(): Promise<void> {
		this.log("unauthorize");
		await this.handleUnauthorize();
		await this.forget();
		this.emitUnauthorized();
	}

	async forget(): Promise<void> {
		this.log("forget");
		await Preferences.remove({ key: this.#taggedKey });
	}

	async remember(data: Data): Promise<void> {
		this.log("remember");
		await Preferences.set({ key: this.#taggedKey, value: JSON.stringify(data) });
	}

	async getRemembered(): Promise<Maybe<Data>> {
		const { value } = await Preferences.get({ key: this.#taggedKey });
		return value && JSON.parse(value);
	}
}
