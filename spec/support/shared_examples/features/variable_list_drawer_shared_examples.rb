# frozen_string_literal: true

RSpec.shared_examples 'variable list drawer' do
  it 'renders the list drawer' do
    open_drawer

    expect(page).to have_selector('[data-testid="ci-variable-drawer"]')
  end

  it 'adds a new CI variable' do
    open_drawer

    fill_variable('NEW_KEY', 'NEW_VALUE')
    click_add_variable

    wait_for_requests

    page.within('[data-testid="ci-variable-table"]') do
      expect(first(".js-ci-variable-row td[data-label='#{s_('CiVariables|Key')}']")).to have_content('NEW_KEY')

      click_button('Reveal values')

      expect(first(".js-ci-variable-row td[data-label='#{s_('CiVariables|Value')}']")).to have_content('NEW_VALUE')
    end
  end

  it 'allows variable with empty value to be created' do
    open_drawer

    fill_variable('NEW_KEY')

    page.within('[data-testid="ci-variable-drawer"]') do
      expect(find_button('Add variable', disabled: false)).to be_present
    end
  end

  it 'defaults to unmasked, expanded' do
    open_drawer

    fill_variable('NEW_KEY')
    click_add_variable

    wait_for_requests

    page.within('[data-testid="ci-variable-table"]') do
      key_column = first(".js-ci-variable-row:nth-child(1) td[data-label='#{s_('CiVariables|Key')}']")

      expect(key_column).not_to have_content(s_('CiVariables|Masked'))
      expect(key_column).to have_content(s_('CiVariables|Expanded'))
    end
  end

  context 'with application setting for protected attribute' do
    context 'when application setting is true' do
      before do
        stub_application_setting(protected_ci_variables: true)

        visit page_path
      end

      it 'defaults to protected' do
        open_drawer

        page.within('[data-testid="ci-variable-drawer"]') do
          expect(find('[data-testid="ci-variable-protected-checkbox"]')).to be_checked
        end
      end
    end

    context 'when application setting is false' do
      before do
        stub_application_setting(protected_ci_variables: false)

        visit page_path
      end

      it 'defaults to unprotected' do
        open_drawer

        page.within('[data-testid="ci-variable-drawer"]') do
          expect(find('[data-testid="ci-variable-protected-checkbox"]')).not_to be_checked
        end
      end
    end
  end

  it 'edits a variable' do
    key_column = first(".js-ci-variable-row td[data-label='#{s_('CiVariables|Key')}']")
    value_column = first(".js-ci-variable-row td[data-label='#{s_('CiVariables|Value')}']")

    expect(key_column).to have_content('test_key')
    expect(key_column).not_to have_content(s_('CiVariables|Protected'))
    expect(key_column).to have_content(s_('CiVariables|Masked'))
    expect(key_column).to have_content(s_('CiVariables|Expanded'))

    click_button('Edit')

    fill_variable('EDITED_KEY', 'EDITED_VALUE')
    toggle_protected
    toggle_masked
    toggle_expanded
    find_by_testid('ci-variable-confirm-button').click

    wait_for_requests

    page.within('[data-testid="ci-variable-table"]') do
      expect(key_column).to have_content('EDITED_KEY')
      expect(key_column).to have_content(s_('CiVariables|Protected'))
      expect(key_column).not_to have_content(s_('CiVariables|Masked'))
      expect(key_column).not_to have_content(s_('CiVariables|Expanded'))

      click_button('Reveal values')

      expect(value_column).to have_content('EDITED_VALUE')
    end
  end

  it 'shows validation error for duplicate keys' do
    open_drawer

    fill_variable('NEW_KEY', 'NEW_VALUE')
    click_add_variable

    wait_for_requests

    open_drawer

    fill_variable('NEW_KEY', 'NEW_VALUE')
    click_add_variable

    wait_for_requests

    expect(find('.flash-container')).to be_present
    expect(find('[data-testid="alert-danger"]').text).to have_content('(NEW_KEY) has already been taken')
  end

  it 'shows validation error for unmaskable values' do
    open_drawer

    toggle_masked
    fill_variable('EMPTY_MASK_KEY', '???')

    # rubocop:disable Layout/LineLength -- error message is too long
    expect(page).to have_content('This value cannot be masked because it contains the following characters: ?. The value must have at least 8 characters.')
    # rubocop:enable Layout/LineLength

    page.within('[data-testid="ci-variable-drawer"]') do
      expect(find_button('Add variable', disabled: true)).to be_present
    end
  end

  it 'handles multiple edits and a deletion' do
    # Create two variables
    open_drawer
    fill_variable('akey', 'akeyvalue')
    click_add_variable

    wait_for_requests

    open_drawer
    fill_variable('zkey', 'zkeyvalue')
    click_add_variable

    wait_for_requests

    expect(page).to have_selector('.js-ci-variable-row', count: 3)

    # Remove the `akey` variable
    page.within('[data-testid="ci-variable-table"]') do
      page.within('.js-ci-variable-row:first-child') do
        click_button('Edit')
      end
    end

    page.within('[data-testid="ci-variable-drawer"]') do
      click_button('Delete variable') # opens confirmation modal
    end

    page.within('[data-testid="ci-variable-drawer-confirm-delete-modal"]') do
      click_button('Delete')
    end

    wait_for_requests

    # Add another variable
    open_drawer
    fill_variable('ckey', 'ckeyvalue')
    click_add_variable

    wait_for_requests

    # expect to find 3 rows of variables in alphabetical order
    expect(page).to have_selector('.js-ci-variable-row', count: 3)
    rows = all('.js-ci-variable-row')
    expect(rows[0].find('td[data-label="Key"]')).to have_content('ckey')
    expect(rows[1].find('td[data-label="Key"]')).to have_content('test_key')
    expect(rows[2].find('td[data-label="Key"]')).to have_content('zkey')
  end

  private

  def open_drawer
    page.within('[data-testid="ci-variable-table"]') do
      click_button('Add variable')
    end
  end

  def click_add_variable
    page.within('[data-testid="ci-variable-drawer"]') do
      click_button('Add variable')
    end
  end

  def fill_variable(key, value = '')
    wait_for_requests

    page.within('[data-testid="ci-variable-drawer"]') do
      find('[data-testid="ci-variable-key"] input').set(key)
      find('[data-testid="ci-variable-value"]').set(value) if value.present?
    end
  end

  def toggle_protected
    page.within('[data-testid="ci-variable-drawer"]') do
      find('[data-testid="ci-variable-protected-checkbox"]').click
    end
  end

  def toggle_masked
    page.within('[data-testid="ci-variable-drawer"]') do
      find('[data-testid="ci-variable-masked-checkbox"]').click
    end
  end

  def toggle_expanded
    page.within('[data-testid="ci-variable-drawer"]') do
      find('[data-testid="ci-variable-expanded-checkbox"]').click
    end
  end
end
