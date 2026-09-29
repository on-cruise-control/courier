import { computed } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import format from 'date-fns/format';
import parseISO from 'date-fns/parseISO';
import subDays from 'date-fns/subDays';
import { ATTRIBUTION_DIMENSIONS as DIMENSIONS } from './attributionDimensions';

const QUERY_DATE_FORMAT = 'yyyy-MM-dd';
const DEFAULT_DATE_RANGE = () => [subDays(new Date(), 30), new Date()];
const DEFAULT_FILTERS = () => ({
  adTitle: '',
  utmSource: '',
  utmMedium: '',
  utmCampaign: '',
  utmTerm: '',
  utmContent: '',
});

export function useAttributionFilterQuery() {
  const route = useRoute();
  const router = useRouter();

  const dateRange = computed(() => {
    const { from, to } = route.query;
    if (from && to) {
      return [parseISO(from), parseISO(to)];
    }
    return DEFAULT_DATE_RANGE();
  });

  const selectedFilters = computed(() => {
    const filters = DEFAULT_FILTERS();
    DIMENSIONS.forEach(dimension => {
      filters[dimension.filterKey] = route.query[dimension.key] || '';
    });
    return filters;
  });

  const buildFilterPayload = () => ({
    fromDate: format(dateRange.value[0], QUERY_DATE_FORMAT),
    toDate: format(dateRange.value[1], QUERY_DATE_FORMAT),
    adTitle: selectedFilters.value.adTitle,
    utmSource: selectedFilters.value.utmSource,
    utmMedium: selectedFilters.value.utmMedium,
    utmCampaign: selectedFilters.value.utmCampaign,
    utmTerm: selectedFilters.value.utmTerm,
    utmContent: selectedFilters.value.utmContent,
  });

  const setFiltersQuery = (nextDateRange, nextFilters) => {
    const query = {
      from: format(nextDateRange[0], QUERY_DATE_FORMAT),
      to: format(nextDateRange[1], QUERY_DATE_FORMAT),
    };
    DIMENSIONS.forEach(dimension => {
      const value = nextFilters[dimension.filterKey];
      if (value) query[dimension.key] = value;
    });
    return router.replace({ query });
  };

  return {
    dateRange,
    selectedFilters,
    buildFilterPayload,
    setFiltersQuery,
    DEFAULT_DATE_RANGE,
    DEFAULT_FILTERS,
  };
}
