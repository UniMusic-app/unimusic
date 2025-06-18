import { useIDBKeyval } from "@vueuse/integrations/useIDBKeyval.mjs";
import { defineStore } from "pinia";

import { generateImageStyle } from "@/utils/songs";
import { EitherType, Maybe } from "@/utils/types";

export interface LocalImageStyle {
	fgColor: string;
	bgColor: string;
	bgGradient: string;
}

export type LocalImageSize = "small" | "large";

// NOTE: We don't store Blob in IndexedDB because of Safari's shenanigans: https://stackoverflow.com/a/70253220/14053734
interface ImageData {
	buffers: { [size in LocalImageSize]?: ArrayBuffer };
	type: string;
	style?: LocalImageStyle;
}

interface IndirectImageData {
	key: string;
}

type LocalImageInfo = { [id in string]?: IndirectImageData | ImageData };

export type LocalImage = EitherType<
	[{ id: string }, { url: string; style?: Partial<LocalImageStyle> }]
>;

function isIndirect(imageData?: ImageData | IndirectImageData): imageData is IndirectImageData {
	return imageData ? "key" in imageData : false;
}

function isDirect(imageData?: ImageData | IndirectImageData): imageData is ImageData {
	return imageData ? !("key" in imageData) : false;
}

interface ImageCacheData {
	style?: LocalImageStyle;
	sizes: {
		[size in LocalImageSize]?: {
			url: string;
			unregisterToken: WeakRef<Blob>;
		};
	};
}

export const useLocalImages = defineStore("LocalImages", () => {
	const localImageInfo = useIDBKeyval<LocalImageInfo>("localImageInfo", {});
	const cachedImageData = new Map<string, ImageCacheData>();

	// eslint-disable-next-line @typescript-eslint/no-unused-vars
	function log(...args: unknown[]): void {
		// console.debug("%cLocalImageStore:", "color: #40080; font-weight: bold;", ...args);
	}

	const registry = new FinalizationRegistry((id: string) => {
		log(`Cleaned up ${id}`);
		cachedImageData.delete(id);
	});

	function unregisterImage(id: string, size: LocalImageSize): boolean {
		const cached = cachedImageData.get(id);
		if (!cached) return false;

		log(`Unregister ${id}/${size}`);

		const token = cached.sizes[size]?.unregisterToken;
		if (!token) return false;

		delete cached.sizes[size];
		if (!Object.keys(cached.sizes).length) {
			cachedImageData.delete(id);
		}
		return registry.unregister(token);
	}

	function removeImage(id: string): void {
		log(`Removing ${id}`);
		delete localImageInfo.data.value[id];
		unregisterImage(id, "small");
		unregisterImage(id, "large");
	}

	function registerImage(
		id: string,
		imageData: ImageData,
		size: "small" | "large",
		unregister = true,
	): string {
		log(`Register ${id}`);

		if (unregister) {
			// If image is already registered, we unregister it
			// To prevent removing cache entry after the previous Blob got freed
			unregisterImage(id, size);
		}

		let image = imageData.buffers[size];
		if (!image) {
			size = "large";
			image = imageData.buffers[size];
		}

		if (!image) {
			throw new Error(`Failed to register image ${id} with size ${size}, image doesn't exist`);
		}

		const blob = new Blob([image], { type: imageData.type });
		const blobUrl = URL.createObjectURL(blob);
		const blobRef = new WeakRef(blob);

		let cachedData = cachedImageData.get(id);
		if (cachedData) {
			cachedData.sizes[size] = { url: blobUrl, unregisterToken: blobRef };
		} else {
			cachedData = {
				sizes: { [size]: { url: blobUrl, unregisterToken: blobRef } },
				style: imageData.style,
			};
		}
		cachedImageData.set(id, cachedData);

		registry.register(blob, id, blobRef);
		return blobUrl;
	}

	async function resizeImage(
		image: Blob,
		resize: { maxWidth: number; maxHeight: number },
	): Promise<Maybe<Blob>> {
		const img = new Image();
		const tempBlobUrl = URL.createObjectURL(image);
		img.src = tempBlobUrl;
		try {
			await new Promise((resolve, reject) => {
				img.onload = resolve;
				img.onerror = reject;
			});
		} catch (error) {
			log("Failed resizing image", error);
			return;
		}

		const scale = Math.min(resize.maxWidth / img.width, resize.maxHeight / img.height);

		if (scale >= 1) {
			log("Aborting resizing, image is already smaller than max{Width,Height}");
			return;
		}

		const scaledWidth = img.width * scale;
		const scaledHeight = img.height * scale;

		const canvas = document.createElement("canvas");
		canvas.width = scaledWidth;
		canvas.height = scaledHeight;

		const context = canvas.getContext("2d");
		if (!context) {
			log("Aborting resizing, failed to create canvas context");
			return;
		}

		context.drawImage(img, 0, 0, scaledWidth, scaledHeight);

		const resizedImage = await new Promise<Blob | null>((resolve) => {
			canvas.toBlob(resolve, image.type);
		});

		if (resizedImage) {
			log("Resized image");
			return resizedImage;
		} else {
			log("Failed to retrieve resized image");
		}

		URL.revokeObjectURL(tempBlobUrl);
	}

	async function associateImage(
		id: string,
		image: Blob,
		resize?: { maxWidth: number; maxHeight: number },
	): Promise<void> {
		if (resize) {
			log(`Resizing ${id} to ${resize.maxWidth}x${resize.maxHeight}`);
			const resized = await resizeImage(image, resize);
			if (resized) image = resized;
		}

		const smallImage = await resizeImage(image, { maxWidth: 128, maxHeight: 128 });

		const [large, small, style] = await Promise.all([
			image.arrayBuffer(),
			smallImage?.arrayBuffer(),
			generateImageStyle(image),
		]);

		const imageData: ImageData = {
			buffers: { large, small },
			type: image.type,
			style,
		};

		localImageInfo.data.value[id] = imageData;

		// If image was already registered, re-register it
		// Otherwise it will be lazily registered when needed
		if (unregisterImage(id, "small")) registerImage(id, imageData, "small");
		if (unregisterImage(id, "large")) registerImage(id, imageData, "large");
	}

	function getUrl(localImage: LocalImage, size: LocalImageSize): Maybe<string> {
		log("getUrl", localImage?.url ?? localImage?.id, size);

		if (localImage?.url) {
			return localImage.url;
		} else if (localImage?.id) {
			return getBlobUrl(localImage.id!, size);
		}
	}

	function getStyle(id?: string): Maybe<LocalImageStyle> {
		log("getStyle", id);
		if (!id) {
			return;
		}

		const cached = cachedImageData.get(id);
		if (cached) {
			return cached.style;
		}
	}

	function getBlobUrl(id: string, size: LocalImageSize): Maybe<string> {
		log("getBlobUrl", id, size);

		const cached = cachedImageData.get(id);
		if (cached?.sizes[size]) return cached.sizes[size].url;

		const imageData = localImageInfo.data.value?.[id];
		if (imageData) {
			if (isIndirect(imageData)) {
				log(`getBlobUrl -> indirect (${imageData.key})`);
				return getBlobUrl(imageData.key, size);
			}
			return registerImage(id, imageData, size);
		}

		log("getBlobUrl -> image missing");
	}

	function getDataOrExternalUrl(localImage: LocalImage, size: LocalImageSize): Maybe<string> {
		log("getDataOrExternalUrl", localImage?.url ?? localImage?.id);

		if (localImage.url) return localImage.url;

		let imageData = localImageInfo.data.value?.[localImage.id!];
		while (isIndirect(imageData)) {
			log(`getDataOrExternalUrl -> indirect (${imageData.key})`);
			imageData = localImageInfo.data.value?.[imageData.key!];
		}

		if (!imageData?.buffers[size]) {
			log(`getDataOrExternalUrl -> image of size ${size} missing`);
			return;
		}

		const fileReader = new FileReader();
		fileReader.readAsDataURL(new Blob([imageData.buffers[size]]));
		const dataUrl = fileReader.result as string;

		return dataUrl;
	}

	// Deduplicate images
	// Only one original copy is kept, and duplicates are pointer to that image
	function deduplicate(): void {
		log("Deduplicate");
		console.time("Deduplicating images");

		const images = Object.entries(localImageInfo.data.value).filter(
			(entry): entry is [string, ImageData] => isDirect(entry[1]),
		);

		for (const size of ["small", "large"] as const) {
			const byteLengthGropped = Map.groupBy(
				images,
				([_key, value]) => value.buffers[size]?.byteLength,
			);

			byteLengthGropped.delete(undefined);

			for (const group of byteLengthGropped.values()) {
				if (group.length === 1) continue;

				// While its probably already safe enough to assume
				// that no one image will have the exact same size
				// we group it by a random one pixel to be extra sure
				const pixelGrouped = Map.groupBy(group, ([_key, value]) => {
					const byte = Math.floor(value.buffers[size]!.byteLength / 3);
					const view = new Uint8Array(value.buffers[size]!.slice(byte, 1));
					return view[0];
				});

				for (const pixelGroup of pixelGrouped.values()) {
					if (pixelGroup.length === 1) continue;

					const indirectImageData: IndirectImageData = { key: pixelGroup[0]![0]! };
					for (let i = 1; i < pixelGroup.length; i++) {
						const [key] = pixelGroup[i]!;
						// Remove duplicated data
						removeImage(key);
						// Link the images
						localImageInfo.data.value[key] = indirectImageData;
					}
				}
			}
		}

		console.timeEnd("Deduplicating images");
	}

	function clearImages(): void {
		localImageInfo.data.value = {};
		for (const id of cachedImageData.keys()) {
			unregisterImage(id, "small");
			unregisterImage(id, "large");
		}
		cachedImageData.clear();
	}

	return {
		clearImages,

		associateImage,
		getUrl,
		getBlobUrl,
		getDataOrExternalUrl,
		getStyle,
		deduplicate,
	};
});
