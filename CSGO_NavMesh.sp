
Address TheNavAreas;
Address navarea_count;

//You want to do this in OnMapStart or else after a map change you will have a bad address
public void OnMapStart()
{
    Handle hConf = LoadGameConfigFile("test.txt");
    
    navarea_count = GameConfGetAddress(hConf, "navarea_count");
    PrintToServer("Found \"navarea_count\" @ 0x%X", navarea_count);
    
    PrintToServer("- \"navarea_count\" = %i", (LoadFromAddress(navarea_count, NumberType_Int32)));
    
    //TheNavAreas is nicely above navarea_count
    TheNavAreas = view_as<Address>(LoadFromAddress(navarea_count + view_as<Address>(0x4), NumberType_Int32));
    PrintToServer("Found \"TheNavAreas\" @ 0x%X", TheNavAreas);
    
    delete hConf;
}  

