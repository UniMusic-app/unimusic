import { useIDBKeyval } from "@vueuse/integrations/useIDBKeyval.mjs";
import { defineStore } from "pinia";

import { blobToBase64 } from "@/utils/buffer";
import { generateBlobHash } from "@/utils/crypto";
import { getPlatform, isElectron } from "@/utils/os";
import { generateImageStyle } from "@/utils/songs";
import { Maybe } from "@/utils/types";
import { Capacitor } from "@capacitor/core";
import { Directory, Filesystem } from "@capacitor/filesystem";

export interface LocalImageStyle {
	fgColor: string;
	bgColor: string;
	bgGradient: string;
}

export type LocalImageSize = "small" | "large";

interface ImageData {
	sizes: { [size in LocalImageSize]?: string };
	hash?: number;
	style?: LocalImageStyle;
}

interface IndirectImageData {
	key: string;
}

type LocalImageInfo = { [id in string]?: IndirectImageData | ImageData };

export interface LocalImage {
	id?: string;
	url?: string;
	style?: Partial<LocalImageStyle>;
}

function isDirect(imageData?: ImageData | IndirectImageData): imageData is ImageData {
	return imageData ? !("key" in imageData) : false;
}

export const useLocalImages = defineStore("LocalImages", () => {
	let LOCAL_IMAGES_DIRECTORY: string;
	queueMicrotask(async () => {
		LOCAL_IMAGES_DIRECTORY = isElectron()
			? `${await ElectronBridge!.fileSystem.getUserDataPath()}/LocalImages`
			: "LocalImages";
	});

	const localImageInfo = useIDBKeyval<LocalImageInfo>("localImageInfo", {});

	function log(...args: unknown[]): void {
		console.debug("%cLocalImageStore:", "color: #40080; font-weight: bold;", ...args);
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

	function getFileName(id: string, size: LocalImageSize): string {
		const fileName = `${id}-${size}`;
		return fileName;
	}
	function getFilePath(id: string, size: LocalImageSize): string {
		const fileName = getFileName(id, size);
		const filePath = `${LOCAL_IMAGES_DIRECTORY}/${fileName}`;
		return filePath;
	}

	async function removeImage(id: string, size: LocalImageSize): Promise<void> {
		const fileName = getFileName(id, size);
		const filePath = getFilePath(id, size);

		log(`removeImage ${id}`);
		const image = localImageInfo.data.value[id];
		if (!isDirect(image)) {
			log(`removeImage ${id}, skipping - indirect image`);
			return;
		}

		switch (getPlatform()) {
			case "web":
				throw new Error("Unimplemented");
			case "electron": {
				await fetch(`local-images://${fileName}`, {
					method: "DELETE",
				});
				break;
			}
			default: {
				await Filesystem.deleteFile({
					path: filePath,
					directory: Directory.Library,
				});
				break;
			}
		}

		delete image.sizes[size];
	}

	async function saveImage(id: string, image: Blob, size: LocalImageSize): Promise<string> {
		const fileName = getFileName(id, size);
		const filePath = getFilePath(id, size);

		switch (getPlatform()) {
			case "web":
				throw new Error("Unimplemented");
			case "electron": {
				const formData = new FormData();
				formData.append("image", image);

				await fetch(`local-images://${fileName}`, {
					method: "PUT",
					body: formData,
				});
				break;
			}
			default: {
				await Filesystem.writeFile({
					data: await blobToBase64(image),
					path: filePath,
					directory: Directory.Library,
					recursive: true,
				});
				break;
			}
		}

		return fileName;
	}

	async function associateImage(id: string, image: Blob): Promise<void> {
		if (getPlatform() === "web") {
			const style = await generateImageStyle(image);
			const imageData: ImageData = { sizes: {}, style };
			localImageInfo.data.value[id] = imageData;
			return;
		}

		const largeImage = await resizeImage(image, { maxWidth: 1024, maxHeight: 1024 });
		const smallImage = await resizeImage(image, { maxWidth: 128, maxHeight: 128 });

		const style = await generateImageStyle(image);
		const hash = await generateBlobHash(image);

		const imageData: ImageData = {
			sizes: {},
			style,
			hash,
		};

		if (largeImage) {
			imageData.sizes.large = await saveImage(id, largeImage, "large");
		} else {
			log(`Failed resizing ${id} to max 1024x1024`);
			imageData.sizes.large = await saveImage(id, image, "large");
		}

		if (smallImage) {
			imageData.sizes.small = await saveImage(id, smallImage, "small");
		} else {
			log(`Failed resizing ${id} to max 128x128`);
		}

		localImageInfo.data.value[id] = imageData;
	}

	async function getUrl(localImage: LocalImage, size: LocalImageSize): Promise<Maybe<string>> {
		log("getUrl", localImage?.url ?? localImage?.id, size);

		if (localImage?.id) {
			const imageData = localImageInfo.data.value[localImage.id];
			if (!imageData) return localImage?.url;

			const direct = resolveDirect(imageData);
			const fileName = direct?.sizes[size];

			if (!fileName) return localImage.url;

			switch (getPlatform()) {
				case "web":
					break;
				case "electron": {
					return `local-images://${fileName}`;
				}
				default: {
					const { uri } = await Filesystem.getUri({
						path: `${LOCAL_IMAGES_DIRECTORY}/${fileName}`,
						directory: Directory.Library,
					});
					return Capacitor.convertFileSrc(uri);
				}
			}
		}

		if (localImage?.url) {
			return localImage.url;
		}
	}

	async function getUri(localImage: LocalImage, size: LocalImageSize): Promise<string | undefined> {
		log("getUri", localImage?.id, size);
		if (!localImage.id) return;

		const fileName = getFileName(localImage.id, size);
		const { uri } = await Filesystem.getUri({
			path: `${LOCAL_IMAGES_DIRECTORY}/${fileName}`,
			directory: Directory.Library,
		});
		return uri;
	}

	function resolveDirect(imageData: ImageData | IndirectImageData): Maybe<ImageData> {
		if (isDirect(imageData)) {
			return imageData;
		} else {
			const direct = localImageInfo.data.value[imageData.key];
			if (!direct) return;
			return resolveDirect(direct);
		}
	}

	function getStyle(id?: string): Maybe<LocalImageStyle> {
		log("getStyle", id);
		if (!id) return;

		const imageData = localImageInfo.data.value[id];
		if (!imageData) return;

		if (isDirect(imageData)) {
			return imageData.style;
		} else {
			return getStyle(imageData.key);
		}
	}

	// Deduplicate images
	// Only one original copy is kept, and duplicates are pointer to that image
	async function deduplicate(): Promise<void> {
		log("Deduplicate");
		console.time("Deduplicating images");
		let deduplicated = 0;

		const images = Object.entries(localImageInfo.data.value).filter(
			(entry): entry is [string, ImageData] => isDirect(entry[1]),
		);

		const grouped = Map.groupBy(images, (item) => item[1].hash ?? "unhashed");
		grouped.delete("unhashed");

		for (const [_, images] of grouped) {
			if (images.length === 1) continue;

			const indirectImageData: IndirectImageData = {
				key: images[0]![0],
			};

			deduplicated += images.length - 1;
			for (let i = 1; i < images.length; ++i) {
				const [id, image] = images[i]!;
				for (const size of Object.keys(image.sizes) as LocalImageSize[]) {
					await removeImage(id, size);
				}
				localImageInfo.data.value[id] = indirectImageData;
			}
		}

		console.log("Deduplicated", deduplicated, "images");
		console.timeEnd("Deduplicating images");
	}

	async function clearImages(): Promise<void> {
		const images = localImageInfo.data.value;
		for (const [id, image] of Object.entries(images)) {
			if (isDirect(image)) {
				for (const size of Object.keys(image.sizes) as LocalImageSize[]) {
					await removeImage(id, size);
				}
				delete localImageInfo.data.value[id];
			} else {
				delete localImageInfo.data.value[id];
			}
		}
	}

	return {
		clearImages,

		associateImage,
		getUrl,
		getUri,
		getStyle,
		deduplicate,
	};
});
