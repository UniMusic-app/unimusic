import { ref } from "vue";

import { Service } from "@/services/Service";
import { Maybe } from "@/utils/types";

export class AuthorizedEvent<State> extends CustomEvent<State> {
	constructor(state: State) {
		super("authorized", { detail: state });
	}
}

export class UnauthorizedEvent extends CustomEvent<never> {
	constructor() {
		super("unauthorized");
	}
}

export abstract class AuthorizationService<const State = unknown> extends Service<State> {
	authorized = ref(false);

	constructor() {
		super();

		this.addEventListener("authorized", () => (this.authorized.value = true));
		this.addEventListener("unauthorized", () => (this.authorized.value = false));
	}

	addEventListener(
		type: "authorized" | "unauthorized",
		callback: EventListenerOrEventListenerObject | null,
		options?: AddEventListenerOptions | boolean,
	): void {
		super.addEventListener(type, callback, options);
	}

	emitAuthorized(state: State): boolean {
		return this.dispatchEvent(new AuthorizedEvent(state));
	}
	emitUnauthorized(): boolean {
		return this.dispatchEvent(new UnauthorizedEvent());
	}
	emitAppropriate(state?: Maybe<State>): boolean {
		if (state) return this.emitAuthorized(state);
		return this.emitUnauthorized();
	}

	abstract handlePassivelyAuthorize(): Promise<Maybe<State>> | Maybe<State>;
	async passivelyAuthorize(): Promise<Maybe<State>> {
		this.log("passivelyAuthorize");
		const state = await this.handlePassivelyAuthorize();
		this.emitAppropriate(state);
		if (state) {
			await this.saveState(state);
		}
		return state;
	}

	abstract handleAuthorize(): Promise<State> | State;
	async authorize(): Promise<State> {
		this.log("authorize");
		const state = await this.handleAuthorize();
		this.emitAuthorized(state);
		await this.saveState(state);
		return state;
	}

	abstract handleUnauthorize(): Promise<void> | void;
	async unauthorize(): Promise<void> {
		this.log("unauthorize");
		await this.handleUnauthorize();
		await this.clearState();
		this.emitUnauthorized();
	}
}
