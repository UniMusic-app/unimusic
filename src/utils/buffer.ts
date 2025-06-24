export async function blobToBase64(blob: Blob): Promise<string> {
	return new Promise((resolve, reject) => {
		const reader = new FileReader();

		reader.onerror = reject;
		reader.onload = (): void => resolve(reader.result as string);

		reader.readAsDataURL(blob);
	});
}
