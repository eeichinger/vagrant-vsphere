require 'rbvmomi'
require 'i18n'
require 'vSphere/action/vim_helpers'

module VagrantPlugins
  module VSphere
    module Action
      class Clone
        include VimHelpers

        def initialize(app, env)
          @app = app
        end

        def call(env)
          config = env[:machine].provider_config

          dc = get_datacenter env[:vSphere_connection], env[:machine]
          template = dc.find_vm config.template_name

#          raise Errors::VSphereError, :message => I18n.t('errors.missing_template') if template.nil?
          raise I18n.t('errors.missing_template') + ":" + config.template_name if template.nil?

          begin
            location = RbVmomi::VIM.VirtualMachineRelocateSpec :pool => get_resource_pool(env[:vSphere_connection], env[:machine])

			custName = RbVmomi::VIM.CustomizationVirtualMachineName
			custLinPrep = RbVmomi::VIM.CustomizationLinuxPrep :hostName => custName, :domain => "local"

			custGlobalIPSettings = RbVmomi::VIM.CustomizationGlobalIPSettings

			custIP = RbVmomi::VIM.CustomizationDhcpIpGenerator
			custIPSettings = RbVmomi::VIM.CustomizationIPSettings :ip => custIP #, :gateway, :subnetMask
			custAdapterMapping = RbVmomi::VIM.CustomizationAdapterMapping :adapter => custIPSettings

			cust_adapter_mapping_list = [custAdapterMapping]

        	custSpec = RbVmomi::VIM.CustomizationSpec :identity => custLinPrep, :globalIPSettings => custGlobalIPSettings, :nicSettingMap => cust_adapter_mapping_list

            spec = RbVmomi::VIM.VirtualMachineCloneSpec :location => location, :powerOn => true, :template => false, :customization => custSpec

            env[:ui].info I18n.t('vsphere.creating_cloned_vm')
            env[:ui].info " -- Template VM: #{config.template_name}"
            env[:ui].info " -- Name: #{config.name}"

            new_vm = template.CloneVM_Task(:folder => template.parent, :name => config.name, :spec => spec).wait_for_completion
#          rescue Exception => e
#            raise :messe.message
          end

          #TODO: handle interrupted status in the environment, should the vm be destroyed?

          env[:machine].id = new_vm.config.uuid

          @app.call env
        end
      end
    end
  end
end