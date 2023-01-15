class MSEventListener_StrategyListener extends X2EventListener;

// Used for a hacky way to spawn the DD_DropShipMatinee_Actor through MSEventListenerTemplate.

static function array<X2DataTemplate> CreateTemplates()
{
	local array<X2DataTemplate> Templates;

	Templates.AddItem(CreateListenerTemplate());

	return Templates;
}

static function MSEventListenerTemplate CreateListenerTemplate()
{
	local MSEventListenerTemplate Template;

	`CREATE_X2TEMPLATE(class'MSEventListenerTemplate', Template, 'WOTCIridarDynamicDeployment_Dummy');

	Template.RegisterInTactical = true;

	return Template;
}
