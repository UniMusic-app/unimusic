/**
 * This module gets ran on the initialization of Mobile devices
 * @module
 */

declare global {
	// eslint-disable-next-line no-var
	var capacitorFetch: typeof window.fetch;
}

const capacitorPatchedFetch = window.fetch;
const webFetch = "CapacitorWebFetch" in window && (window.CapacitorWebFetch as typeof window.fetch);

if (webFetch) {
	window.fetch = webFetch;
	window.capacitorFetch = capacitorPatchedFetch;
}

export {};
