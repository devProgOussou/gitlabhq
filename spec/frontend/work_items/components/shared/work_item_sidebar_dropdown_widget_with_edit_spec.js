import { GlForm, GlCollapsibleListbox, GlLoadingIcon } from '@gitlab/ui';
import { nextTick } from 'vue';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import { __ } from '~/locale';
import WorkItemSidebarDropdownWidgetWithEdit from '~/work_items/components/shared/work_item_sidebar_dropdown_widget_with_edit.vue';

describe('WorkItemSidebarDropdownWidgetWithEdit component', () => {
  let wrapper;

  const findHeader = () => wrapper.find('h3');
  const findEditButton = () => wrapper.findByTestId('edit-button');
  const findApplyButton = () => wrapper.findByTestId('apply-button');

  const findLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);
  const findLabel = () => wrapper.find('label');
  const findForm = () => wrapper.findComponent(GlForm);
  const findCollapsibleListbox = () => wrapper.findComponent(GlCollapsibleListbox);

  const createComponent = ({
    itemValue = null,
    canUpdate = true,
    isEditing = false,
    updateInProgress = false,
  } = {}) => {
    wrapper = mountExtended(WorkItemSidebarDropdownWidgetWithEdit, {
      propsData: {
        dropdownLabel: __('Iteration'),
        dropdownName: 'iteration',
        listItems: [],
        itemValue,
        canUpdate,
        updateInProgress,
        headerText: __('Select iteration'),
      },
    });

    if (isEditing) {
      findEditButton().vm.$emit('click');
    }
  };

  describe('label', () => {
    it('shows header when not editing', () => {
      createComponent();

      expect(findHeader().exists()).toBe(true);
      expect(findHeader().classes('gl-sr-only')).toBe(false);
      expect(findLabel().exists()).toBe(false);
    });

    it('shows label and hides header while editing', async () => {
      createComponent();

      findEditButton().vm.$emit('click');

      await nextTick();

      expect(findLabel().exists()).toBe(true);
      expect(findHeader().classes('gl-sr-only')).toBe(true);
    });
  });

  describe('edit button', () => {
    it('is not shown if user cannot edit', () => {
      createComponent({ canUpdate: false });

      expect(findEditButton().exists()).toBe(false);
    });

    it('is shown if user can edit', () => {
      createComponent({ canUpdate: true });

      expect(findEditButton().exists()).toBe(true);
    });

    it('triggers edit mode on click', async () => {
      createComponent();

      findEditButton().vm.$emit('click');

      await nextTick();

      expect(findLabel().exists()).toBe(true);
      expect(findForm().exists()).toBe(true);
    });

    it('is replaced by Apply button while editing', async () => {
      createComponent();

      findEditButton().vm.$emit('click');

      await nextTick();

      expect(findEditButton().exists()).toBe(false);
      expect(findApplyButton().exists()).toBe(true);
    });
  });

  describe('loading icon', () => {
    it('shows loading icon while update is in progress', async () => {
      createComponent({ updateInProgress: true });

      await nextTick();

      expect(findLoadingIcon().exists()).toBe(true);
    });
  });

  describe('value', () => {
    it('shows None when no item value is set', () => {
      createComponent({ itemValue: null });

      expect(wrapper.text()).toContain('None');
    });
  });

  describe('form', () => {
    it('is not shown while not editing', () => {
      createComponent();

      expect(findForm().exists()).toBe(false);
    });

    it('is shown while editing', async () => {
      createComponent({ isEditing: true });
      await nextTick();

      expect(findForm().exists()).toBe(true);
    });
  });

  describe('Dropdown', () => {
    it('is not shown while not editing', () => {
      createComponent();

      expect(findCollapsibleListbox().exists()).toBe(false);
    });

    it('renders the collapsible listbox with required props', async () => {
      createComponent({ isEditing: true });

      await nextTick();

      expect(findCollapsibleListbox().exists()).toBe(true);
      expect(findCollapsibleListbox().props()).toMatchObject({
        items: [],
        headerText: 'Select iteration',
        category: 'primary',
        loading: false,
        isCheckCentered: true,
        searchable: true,
        searching: false,
        infiniteScroll: false,
        noResultsText: 'No matching results',
        toggleText: 'None',
        searchPlaceholder: 'Search',
        resetButtonLabel: 'Clear',
      });
    });
  });
});
