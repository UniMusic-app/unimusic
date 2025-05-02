import {
	DisplayableArtist,
	Filled,
	filledDisplayableArtist,
	SongType,
} from "@/services/Music/objects";
import { LocalImageStyle } from "@/stores/local-images";

export function formatArtists(artists?: (DisplayableArtist | Filled<DisplayableArtist>)[]): string {
	if (!artists?.length) {
		return "Unknown artist(s)";
	}

	let formatted = filledDisplayableArtist(artists[0]!).title ?? "Unknown Artist";
	for (let i = 1; i < artists.length; ++i) {
		formatted += ` & ${filledDisplayableArtist(artists[i]!).title}`;
	}
	return formatted;
}

export function formatGenres(genres?: string[]): string {
	return genres?.join(", ") || "Unknown genre(s)";
}

export function songTypeToDisplayName(type?: SongType): string {
	switch (type) {
		case "local":
			return "Local";
		case "musickit":
			return "Apple Music";
		case "youtube":
			return "YouTube";
		default:
			return "Unknown service";
	}
}

export function kindToDisplayName(kind?: string): string {
	switch (kind) {
		case "album":
		case "albumPreview":
			return "Album";
		case "song":
		case "songPreview":
			return "Song";
		case "artist":
		case "artistPreview":
			return "Artist";
		default:
			return "Unknown kind";
	}
}

export function colorLuminance([r, g, b]: Uint8ClampedArray): number {
	return r! * 0.2126 + g! * 0.7152 + b! * 0.0722;
}

export function colorValue([r, g, b]: Uint8ClampedArray): number {
	return r! + g! + b!;
}

export function contrastColor(color: Uint8ClampedArray): Uint8ClampedArray {
	if (colorLuminance(color) > 128) {
		return new Uint8ClampedArray([0, 0, 0]);
	} else {
		return new Uint8ClampedArray([255, 255, 255]);
	}
}

export function toCssColor([r, g, b, a = 255]: Uint8ClampedArray): string {
	if (a === 255) {
		return `rgb(${r},${g},${b})`;
	} else {
		return `rgb(${r},${g},${b},${a})`;
	}
}

export async function generateImageStyle(image: Blob): Promise<LocalImageStyle> {
	const RESOLUTION = 256;

	const canvas = document.createElement("canvas");
	canvas.width = RESOLUTION;
	canvas.height = RESOLUTION;

	const context = canvas.getContext("2d", { willReadFrequently: true });
	if (!context) {
		return {
			fgColor: "#ffffff",
			bgColor: "#000000",
			bgGradient: "#000000",
		};
	}

	const bitmap = await createImageBitmap(image);
	context.drawImage(bitmap, 0, 0, RESOLUTION, RESOLUTION);

	const pointsOfInterest: [x: number, y: number][] = [
		[0, 0],
		[0.05, 0.05],
		[0.25, 0.25],

		[0.1, 0.9],
		[0.9, 0.1],
		[0.1, 0.1],
		[0.9, 0.9],
		[0.3, 0.5],
		[0.5, 0.3],

		[0.5, 0.2],
		[0.5, 0.25],

		[0.45, 0.5],
		[0.5, 0.5],
		[0.55, 0.5],

		[0.5, 0.75],
		[0.5, 0.8],

		[0.75, 0.75],
		[0.95, 0.95],
		[1, 1],
	];

	let clampedPoints = 0;
	const uniqueColors = new Set(
		pointsOfInterest.map(([x, y]) => {
			const color = context.getImageData(RESOLUTION * x, RESOLUTION * y, 1, 1).data;

			// If color is very bright - tone it down.
			// It is done so every control in Music Player has no contrast issues.
			const ratio = colorLuminance(color) / 210;
			if (ratio > 1) {
				color[0]! /= ratio;
				color[1]! /= ratio;
				color[2]! /= ratio;
				clampedPoints += 1;
			}

			return color;
		}),
	);
	canvas.remove();

	const colors = Array.from(uniqueColors)
		// Filter out white-ish colors
		.filter((a) => {
			if (colorLuminance(a) < 180) {
				return true;
			}

			const [r, g, b] = a;
			const x = r! / g!;
			const y = g! / b!;
			const z = b! / r!;
			return Math.max(x, y, z) > 1.2 || Math.min(x, y, z) < 0.8;
		})
		.sort((a, b) => colorLuminance(b) - colorLuminance(a));

	// Perfectly balanced, as all things should be
	if (clampedPoints < pointsOfInterest.length / 2) {
		const layers = [];
		const step = Math.round(360 / colors.length);
		for (const [i, [r, g, b]] of colors.entries()) {
			layers.push(`linear-gradient(${step * i}deg, rgb(${r} ${g} ${b} / 80%), transparent 60%)`);
		}

		const bgColor = colors[2] ?? colors[0]!;
		const fgColor = contrastColor(bgColor);

		layers.push(`linear-gradient(rgb(${bgColor[0]}, ${bgColor[1]}, ${bgColor[2]}))`);

		return {
			fgColor: toCssColor(fgColor),
			bgColor: toCssColor(bgColor),
			bgGradient: layers.join(","),
		};
	}

	const accentColors = colors.filter(([r, g, b]) => {
		const x = r! / g!;
		const y = g! / b!;
		const z = b! / r!;
		return Math.max(x, y, z) > 1.2 || Math.min(x, y, z) < 0.8;
	});

	for (const a of accentColors) {
		const aValue = colorValue(a);
		const verySimilar = accentColors.findIndex(
			(b) => b !== a && Math.abs(aValue - colorValue(b)) < 5,
		);
		if (verySimilar !== -1) {
			accentColors.splice(verySimilar, 1);
		}
	}

	if (!accentColors.length) {
		return {
			fgColor: "#121212",
			bgColor: "#dadada",
			bgGradient: `
				linear-gradient(217deg, rgb(173 180 180 / 100%), rgb(173 180 180 / 80%) 70.71%),
				linear-gradient(127deg, rgb(180 173 180 / 100%), rgb(180 173 180 / 80%) 70.71%),
				linear-gradient(336deg, rgb(180 180 173 / 100%), rgb(180 180 173 / 80%) 70.71%)`,
		};
	}

	const layers = ["linear-gradient(white, white)"];
	const step = Math.round(360 / accentColors.length);
	for (const [i, [r, g, b]] of accentColors.entries()) {
		layers.unshift(`linear-gradient(${step * i}deg, rgb(${r} ${g} ${b} / 80%), transparent 70.71%)`);
	}

	const bgColor = accentColors[0]!;
	const fgColor = contrastColor(bgColor);

	return {
		fgColor: toCssColor(fgColor),
		bgColor: toCssColor(bgColor),
		bgGradient: layers.join(","),
	};
}
