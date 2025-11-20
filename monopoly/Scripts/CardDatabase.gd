extends Node2D

const CARDS = { 

	#Format is value of the card and color of the card.
	"DB_ParkPlace": [4,"dblue"],
	"DB_BroadWalk": [4,"dblue"],
	"R_KentuckyAve": [3,"red"],
	"R_Illinois": [3,"red"],
	"R_IndianaAve":[3,"red"],
	"G_NorthCarolinaAve":[4,"green"],
	"G_PacificAve":[4,"green"],
	"G_PennsylvaniaAve":[4,"green"],
	"Y_AtlanticAve":[3,"yellow"],
	"Y_MarvinGardens":[3,"yellow"],
	"Y_VentnorAve":[3,"yellow"],
	"U_WaterWorks":[2,"utility"],
	"U_ElectricCompany":[2,"utility"],
	"RR_BNO":[2,"Railroad"],
	"RR_Penns":[2,"Railroad"],
	"RR_ShortLine":[2,"Railroad"],
	"RR_Reading":[2,"Railroad"],
	"LB_ConnectAve":[1, "lightblue"],
	"LB_OrientalAve":[1, "lightblue"],
	"LB_VermontAve":[1, "lightblue"],
	"P_StatesAve":[2,"pink"],
	"P_StCharlesPlace":[2,"pink"],
	"P_VirginiaAve":[2,"pink"],
	"O_NewYorkAve":[2,"orange"],
	"O_StJamesPlace":[2,"orange"],
	"O_TennAve":[2,"orange"],
	"B_BalticAve":[1,"brown"],
	"B_MediAve":[1,"brown"],
	#Action cards
	"AC_PassGo":[1,"action"], # draw 2 cards
	"AC_DealBreaker":[5,"action"], # steal full set
	"AC_JustSayNo":[4,"action"], #cancel action
	"AC_SlyDeal":[3, "action"], #steal single property
	"AC_ForcedDeal": [3, "action"], #swap properties
	"AC_DebtCollector":[3, "action"], # ask 5M from everyone
	"AC_Birthday":[2,"action"], # Ask 2M from everyone
	"AC_Rent_Generic":[1,"rent"], # charge rent on any color
	"AC_Rent_BlueGreen":[1,"rent"], # charge rent on blue/green
	"Money_10M":[10,"money"],
	"Money_5M":[5,"money"],
	"Money_3M":[3,"money"],
	"Money_2M":[2,"money"],
	"Money_1M":[1,"money"]
}

var COLOURS = { 
	#indicates how many properties each colour needs 
	#to be a full set
	"red": 3,
	"dblue": 2,
	"green": 3,
	"yellow": 3,
	"utility":2,
	"Railroad":4,
	"lightblue":3,
	"pink":3,
	"orange":3,
	"brown": 2
}
func is_property(card_name: String) -> bool:
	if not CARDS.has(card_name): return false
	var type = CARDS[card_name][1]
	return type != "action" and type != "money" and type != "rent"
