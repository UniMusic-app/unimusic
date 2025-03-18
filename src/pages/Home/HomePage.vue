<template>
	<AppPage title="Home">
		<SongItem v-for="{ song, id } in musicPlayer.state.queue" :song :key="id" />
	</AppPage>
</template>

<script setup lang="ts">
import AppPage from "@/components/AppPage.vue";
import SongItem from "@/components/SongItem.vue";

import { useMusicPlayer } from "@/stores/music-player";

const musicPlayer = useMusicPlayer();
</script>
