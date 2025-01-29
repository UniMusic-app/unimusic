import { Service } from "./Service";
import { useIDBKeyvalAsync } from "@/utils/vue";

interface LocalImageInfo {
	[imageId: string]: { image?: Blob; url?: string } | undefined;
}

/**
 * Service which manages blob urls
 */
export class LocalImageManagementService extends Service {
	logName = "LocalImageManagementService";
	logColor = "#704080";

	// TODO: These images should probably get cleaned after a while to not use too much space
	#localImageInfo = useIDBKeyvalAsync<LocalImageInfo>("localImageInfo", {});

	constructor() {
		super();
	}

	async associateImage(
		id: string,
		image: Blob,
		resize?: { width: number; height: number },
	): Promise<void> {
		const localImageInfo = await this.#localImageInfo;

		resize: if (resize) {
			const { width, height } = resize;

			const canvas = document.createElement("canvas");
			canvas.width = width;
			canvas.height = height;

			const context = canvas.getContext("2d");
			if (!context) break resize;

			const blobUrl = URL.createObjectURL(image);

			const img = new Image(width, height);
			img.src = blobUrl;
			await new Promise((resolve, reject) => {
				img.onload = resolve;
				img.onerror = reject;
			});

			context.drawImage(img, 0, 0, width, height);

			const blob = await new Promise<Blob | null>((resolve) => {
				canvas.toBlob(resolve, image.type);
			});

			if (blob) image = blob;
		}

		await this.revokeBlobUrl(id);
		const imageInfo = (localImageInfo.value[id] ??= {});
		imageInfo.image = image;
	}

	async getBlobUrl(id: string): Promise<string | undefined> {
		const localImageInfo = await this.#localImageInfo;
		const imageInfo = localImageInfo.value[id];
		if (!imageInfo?.url && imageInfo?.image) {
			return await this.createBlobUrl(id);
		}
		return imageInfo?.url;
	}

	async createBlobUrl(id: string): Promise<string | undefined> {
		const localImageInfo = await this.#localImageInfo;

		const imageInfo = localImageInfo.value[id];
		if (imageInfo?.url) {
			if (!imageInfo.image) {
				await this.revokeBlobUrl(id);
				return;
			}

			return imageInfo.url;
		}

		if (imageInfo?.image) {
			return URL.createObjectURL(imageInfo.image);
		}
	}

	async revokeBlobUrl(id: string): Promise<void> {
		const localImageInfo = await this.#localImageInfo;

		const imageInfo = localImageInfo.value[id];
		if (imageInfo?.url) {
			URL.revokeObjectURL(imageInfo.url);
			delete imageInfo.url;
		}
	}

	async revokeAllUrls(): Promise<void> {
		const localImageInfo = await this.#localImageInfo;

		for (const key of Object.keys(localImageInfo.value)) {
			this.revokeBlobUrl(key);
		}
	}
}
