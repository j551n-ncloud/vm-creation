public static boolean emptyRole ( TeamManaged tm, String roleID ){
		try{
		Role role = Role.toRole(roleID );
		if( role == null ){
		LOGGER.error("Did not get role for role id: " + roleID );
		return false;
		}
		TeamReference tmTeamID = tm.getTeamId();
		if( (tmTeamID == null) ){
		LOGGER.error( "CR team id role null: " + tmTeamID );
		return false;
		}
		Team crTeam = (Team) tmTeamID.getObject();
@SuppressWarnings("unchecked")
        Enumeration<WTPrincipalReference> crAssigneePrincipalRefs = crTeam.getPrincipalTarget(role );
		while( crAssigneePrincipalRefs.hasMoreElements() ) {
		WTPrincipal existingAssigneePrincipal = crAssigneePrincipalRefs.nextElement().getPrincipal();
		LOGGER.info("Removing principal " + existingAssigneePrincipal + " from role " + role + " in team " + crTeam );
		crTeam.deletePrincipalTarget(role, existingAssigneePrincipal);
		crTeam = (Team)wt.fc.PersistenceHelper.manager.refresh( (Persistable) crTeam );
		}
		return true;
		}catch( WTException wte ){
		LOGGER.error( "Error occurred while assigning role to user", wte );
		return false; // We may in fact have copied some roleID participants, but assume a complete failure => return false
		}
		}