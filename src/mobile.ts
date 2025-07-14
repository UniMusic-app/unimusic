/**
 * This module gets ran on the initialization of Mobile devices
 * @module
 */

declare global {
	var capacitorFetch: typeof window.fetch;
}

const capacitorPatchedFetch = window.fetch;
const webFetch = "CapacitorWebFetch" in window && (window.CapacitorWebFetch as typeof window.fetch);

if (webFetch) {
	window.fetch = webFetch;
	window.capacitorFetch = capacitorPatchedFetch;
}

export {};
