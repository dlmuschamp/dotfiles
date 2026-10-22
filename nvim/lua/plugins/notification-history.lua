return {
  {
    'folke/snacks.nvim',
    keys = {
      { '<leader>n', function() require('config.notification-history').open() end,
        desc = 'Full Notification History' },
    },
    init = function()
      vim.api.nvim_create_user_command('NotificationLog', function()
        require('config.notification-history').open()
      end, { desc = 'Open complete notification messages', force = true })
    end,
  },
}
