<template>
  <nav class="seg mb no-print">
    <RouterLink to="/training/sessions" :class="{ on: $route.path === '/training/sessions' }">รายหลักสูตร</RouterLink>
    <RouterLink to="/training/records" :class="{ on: $route.path === '/training/records' }">รายบุคคล</RouterLink>
  </nav>
</template>
