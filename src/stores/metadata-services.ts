import { Metadata, MetadataLookup, MetadataService } from "@/services/Metadata/MetadataService";
import { Maybe } from "@/utils/types";
import { defineStore } from "pinia";
import { computed, reactive } from "vue";

export const useMetadataServices = defineStore("MetadataServices", () => {
	const registeredServices = reactive<Record<string, MetadataService>>({});
	const enabledServices = computed<MetadataService[]>(() =>
		Object.values(registeredServices)
			.filter((service) => service.enabled.value)
			.sort((a, b) => a.order.value - b.order.value || a.name.localeCompare(b.name)),
	);

	function registerService(service: MetadataService): void {
		registeredServices[service.name] = service;
	}

	function getService(type?: string): Maybe<MetadataService> {
		if (!type) {
			return;
		}

		const service = registeredServices[type];
		if (service?.enabled?.value) {
			return service;
		}
	}

	async function getMetadata(lookup: MetadataLookup): Promise<Maybe<Metadata>> {
		for (const service of enabledServices.value) {
			const metadata = service.getMetadata(lookup);
			if (metadata) return metadata;
		}
	}

	void import("@/services/Metadata/MusicBrainzMetadataService").then((module) =>
		registerService(new module.MusicBrainzMetadataService()),
	);
	void import("@/services/Metadata/AcoustIDMetadataService").then((module) =>
		registerService(new module.AcoustIDMetadataService()),
	);

	return {
		registeredServices,
		enabledServices,
		registerService,

		getService,
		getMetadata,
	};
});
