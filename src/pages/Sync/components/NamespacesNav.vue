<script setup lang="ts">
import {
	IonContent,
	IonHeader,
	IonIcon,
	IonItem,
	IonItemOption,
	IonItemOptions,
	IonItemSliding,
	IonLabel,
	IonList,
	IonNote,
	IonText,
	IonTitle,
	IonToolbar,
} from "@ionic/vue";
import { compass as locationIcon, earthOutline as namespacesIcon } from "ionicons/icons";

import AppPage from "@/components/AppPage.vue";

import { useSync } from "@/stores/sync";

const sync = useSync();
</script>

<template>
	<AppPage title="Namespaces" back-button="Back" :show-content-header="false">
		<ion-content id="namespaces-page-content" class="ion-padding">
			<header>
				<ion-icon :icon="namespacesIcon" color="primary" />
				<ion-header collapse="condense">
					<ion-toolbar>
						<ion-title class="ion-text-nowrap" size="large">Namespaces</ion-title>
					</ion-toolbar>
				</ion-header>
				<ion-note>
					Namespaces represent connections to folder.
					<wbr />
					They can connect multiple people.
				</ion-note>
			</header>

			<ion-list inset lines="full">
				<ion-item-sliding v-for="(path, namespace) in sync.data.namespaces" :key="namespace">
					<ion-item>
						<ion-label>
							<ion-text>{{ namespace }}</ion-text>
							<ion-note>
								<ion-icon :icon="locationIcon" />
								{{ sync.normalizeRelativePath(path) }}
							</ion-note>
						</ion-label>
					</ion-item>

					<ion-item-options>
						<ion-item-option color="danger" @click="sync.deleteNamespace(namespace)">
							Delete
						</ion-item-option>
					</ion-item-options>
				</ion-item-sliding>
			</ion-list>
		</ion-content>
	</AppPage>
</template>

<style>
#namespaces-page-content {
	& > header {
		text-align: center;
		margin-inline: auto;
		margin-bottom: 16px;

		& > ion-icon {
			font-size: 4rem;
			width: 100%;
		}

		& > ion-header {
			margin-inline: auto;
			width: max-content;
		}

		& ion-title {
			transform-origin: top center;
			margin: 0;
		}

		& > ion-note {
			display: inline-block;
			text-wrap: balance;
		}
	}

	& > ion-list {
		background: var(--ion-background-color-step-150, #ebebeb);

		& ion-item {
			--background: var(--ion-background-color-step-150, #ebebeb);

			& > ion-label {
				& > ion-text {
					display: block;
					overflow: hidden;
					white-space: nowrap;
					text-overflow: ellipsis;
				}

				& > ion-note {
					display: flex;
					align-items: center;
					gap: 0.25ch;
					font-weight: 550;
				}
			}
		}
	}
}
</style>
