class X2SitRep_DynamicDeployment extends X2SitRep;

static function array<X2DataTemplate> CreateTemplates()
{
	local array<X2DataTemplate> Templates;
	local X2SitRepTemplate Template;

	`CREATE_X2TEMPLATE(class'X2SitRepTemplate', Template, 'IRI_DD_NoDeploymentSitRep');

	Template.StrategyReqs.SpecialRequirementsFn = AlwaysFail;
	Template.bNegativeEffect = true;

	Templates.AddItem(Template);
	
	return Templates;
}

// Should ensure this sitrep never occurs naturally.
static private function bool AlwaysFail()
{
	return false;
}