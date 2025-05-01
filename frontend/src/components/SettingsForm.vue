<script lang="ts" setup>
import { ref } from 'vue';
import type { User } from '@/types';

const props = defineProps<{
  user: User
  updateBeta: (setting: boolean) => void
}>()

const beta = ref(props.user.beta ? "On" : "Off")

const betaUpdate = async () => props.updateBeta(beta.value == "On")

const updateLanguage = (a: Event) => {
  const target = a.target as HTMLInputElement;
  localStorage.setItem('language', target.value)
}
</script>

<template>
  <div class="page-container">
    <div class="page-content column">
      <h2 class="title">{{$t('settings')}}</h2>

      <fieldset class="box column">
        <legend>{{$t('language')}}</legend>
        <p>{{$t('languageSettingDescription')}}</p>
        <select v-model="$i18n.locale" @change="updateLanguage">
          <option value="en">English</option>
          <option value="it">Italiano</option>
          <option value="es">Español</option>
          <option value="zh">中文</option>
        </select>
      </fieldset>

      <fieldset class="box column">
        <legend>{{$t('enrollInBeta')}}</legend>
        <p>{{$t('enrollInBetaDescription')}}</p>
        <div class="row">
          <label>{{$t('enrollInBetaOn')}} <input type="radio" name="beta" value="On" v-model="beta" @change="betaUpdate" /></label>
          <label>{{$t('enrollInBetaOff')}} <input type="radio" name="beta" value="Off" v-model="beta" @change="betaUpdate" /></label>
        </div>
      </fieldset>
    </div>
  </div>
</template>

<style lang="scss" scoped>
input[type="radio"] {
  display: unset;
}

legend {
 font-size: 1.1em;
 font-weight: bolder;
}
</style>
