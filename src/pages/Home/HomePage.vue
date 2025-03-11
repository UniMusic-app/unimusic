<template>
  <ion-page>
    <AppHeader>
      <template #toolbar>
        <ion-title>Home</ion-title>
      </template>
    </AppHeader>

    <ion-content :fullscreen="true" class="ion-padding">
      <SongItem v-for="item in musicPlayer.queuedSongs" :song="item" :key="item.id" />
    </ion-content>

    <AppFooter />
  </ion-page>
</template>

<script setup lang="ts">
import AppFooter from "@/components/AppFooter.vue";
import AppHeader from "@/components/AppHeader.vue";
import { IonContent, IonPage, IonTitle } from "@ionic/vue";

import SongItem from "@/components/SongItem.vue";
import { useMusicPlayer } from "@/stores/music-player";
const musicPlayer = useMusicPlayer();

musicPlayer.play();
</script>
