%rungetcorr



%%%%%%%%%  Make a heatmap with labeled rows and colums for an ROI by ROI matrix %%%%%%%%

%corrmat=correlation matrix from roi-roi corr excel file output by the
%getroicorr script; replace "Inf" with 1 on diagonal. I just paste this
%into matlab like this:

corrmat=[NaN	0.108954611	0.047385317	0.145385203	0.036248574	0.044224284	0.004373993	0.041180648	0.051053627	0.013129786	0.006496274	-0.033345552	-0.002564576	-0.098719365	-0.026614031	-0.016516386	-0.054516118	0.007011381	0.03223208	0.073511047	0.005558539	0.042599583	-0.033389461	-0.060876934	-0.094219802	-0.046965349	-0.007015203	-0.016909928	-0.034563138	-0.067657116	-0.096715371	-0.142696738	0.066953074	0.023679233	-0.010844779	-0.0555536	0.053865132	-0.044353859	0.049924018	0.078791344	0.177235806	-0.011635962	-0.084542229	0.019512628	0.067641112	-0.143662445	-0.133078844	-0.067904701	-0.097242793	-0.052863049	0.010002757
0.108954611	NaN	0.137187839	0.265655861	0.091179454	0.066346646	0.00173169	0.054091448	-0.023915044	0.023592731	0.033704405	-0.063814156	-0.04725378	-0.128433922	0.029015082	0.076451074	0.051994731	-0.059559904	0.058312084	0.019141777	-0.055594952	0.051065276	-0.078616754	-0.045829645	-0.047738991	-0.026813551	0.002861121	-0.053215828	-0.043432833	-0.043747154	-0.054481416	-0.2114523	-0.085035877	-0.135979787	0.001243317	-0.13017082	-0.010573098	0.003478751	0.050716869	-0.013831141	0.212906957	-0.014102742	-0.06609186	0.142170281	0.00748401	-0.129557634	-0.145124542	-0.150526998	-0.134536184	-0.164733925	-0.147533138
0.047385317	0.137187839	NaN	0.081834652	0.112918987	0.090873692	0.004513395	0.088014519	0.059050573	-0.114278101	-0.130421663	-0.113327914	0.005900026	-0.052368578	-0.115863639	-0.097557521	-0.108879282	-0.068143987	0.007124505	0.044781401	-0.01823134	0.006560797	-0.018639963	0.02373468	0.049525486	0.052022443	-0.038782803	-0.040689893	-0.115196475	-0.14658427	-0.073009574	-0.060118927	0.034733187	0.073269862	0.058842492	0.094229247	0.007339237	0.020540892	0.144944371	0.066079599	0.094177764	0.13501936	0.029358968	0.001915112	0.094605363	0.031127393	-0.011149325	0.002695878	0.008752149	-0.069653952	-0.092077819
0.145385203	0.265655861	0.081834652	NaN	0.154494454	0.062585093	0.11690134	0.167096308	0.138032899	-0.150588781	-0.227494814	-0.229544312	-0.135038258	-0.132431655	-0.134088864	-0.046182967	0.041076237	0.020236361	0.042498302	0.016635976	-0.103599443	-0.030948307	-0.071377022	-0.019000112	0.118290685	0.072304498	-0.104656065	-0.128397174	-0.076092959	-0.095367297	0.006119528	0.015928814	0.003748364	0.000164959	0.006684067	0.056904491	0.128349407	0.124177117	0.150445256	0.05830874	0.150122684	0.057403543	-0.078831105	-0.073259473	0.137081815	-0.003549012	-0.02480174	-0.121214648	-0.094453081	-0.176856034	-0.225954128
0.036248574	0.091179454	0.112918987	0.154494454	NaN	0.059080036	-0.02306601	0.075779556	0.100815292	-0.128245754	-0.139148492	0.038295724	0.042953934	-0.002516719	-0.114847961	-0.018574781	-0.073574285	0.013189401	0.042471434	0.005969032	-0.033417429	-0.017078987	-0.055174049	-0.027080278	0.016390439	-0.034262322	-0.049256954	-0.026945449	-0.131725125	-0.147808616	0.002561472	-0.112248394	-0.001487893	0.045049728	-0.060181	0.054730289	0.04021975	0.010955853	0.091748895	0.036659695	0.100938738	0.022184934	0.008787797	-0.074321486	0.038474372	0.018694065	0.018217867	-0.03175669	-0.06997855	-0.143361434	-0.104465263
0.044224284	0.066346646	0.090873692	0.062585093	0.059080036	NaN	0.120051468	0.1148602	0.152230237	-0.124418758	-0.178023286	0.009795985	0.019844582	-0.073915056	-0.053963808	-0.009150616	-0.012334629	0.008207781	0.047156054	0.026127966	-0.056445012	-0.024854874	0.016064747	0.058634741	0.065601332	-0.068724775	0.112780991	0.046158314	-0.029620323	-0.030740627	0.04756591	-0.04360963	0.04269966	0.083796966	0.00169155	0.132689108	0.079650264	0.070301995	-0.020205437	0.074856085	0.03334437	0.056965203	-0.040638908	-0.071202535	0.098068927	-0.039106213	-0.059664911	0.018752551	0.004261628	-0.256376708	-0.236121364
0.004373993	0.00173169	0.004513395	0.11690134	-0.02306601	0.120051468	NaN	0.120109569	0.024041709	-0.011590381	0.002521139	-0.057836366	-0.137832089	-0.070204763	-0.061542114	-0.035222745	0.01698155	-0.008999133	0.012406318	-0.118820048	-0.016862646	-0.043340038	0.071361904	0.114091402	0.135140266	0.086769682	0.004484064	0.042022173	-0.076760958	-0.110083442	0.005834833	-0.054411245	-0.058942329	0.051308639	0.009748345	-0.058792315	-0.057044736	0.150069737	0.057502991	0.041310408	0.145371496	0.043092614	0.134282218	0.030272295	-0.006703865	-0.018589855	-0.033044153	-0.027198664	0.051159513	0.041053629	0.084521806
0.041180648	0.054091448	0.088014519	0.167096308	0.075779556	0.1148602	0.120109569	NaN	-0.001169168	-0.091230983	-0.103674228	-0.073438182	-0.209483233	-0.160023448	-0.02635372	-0.032473013	0.024832399	-0.039989277	-0.0042605	-0.120503017	-0.074280147	-0.024260612	0.028442299	0.044322808	0.155181809	0.063051291	-0.017255237	0.002772316	-0.065054884	-0.126125831	-0.00754612	-0.1377317	0.003498842	0.05561028	-0.062867201	-0.025987634	-0.112526437	-0.037991576	-0.046939211	-0.024549321	0.063363728	-0.010634392	0.077775972	0.000304305	-0.068023625	-0.032967714	-0.033632783	0.010276659	0.117616588	0.019892648	0.021751506
0.051053627	-0.023915044	0.059050573	0.138032899	0.100815292	0.152230237	0.024041709	-0.001169168	NaN	-0.062554734	0.017636412	-0.109921487	-0.107194599	0.006950511	0.009914222	0.110611542	0.090182626	0.115326636	-0.084393206	0.057687327	-1.85E-02	0.083842442	-0.066222009	-0.021798913	-0.040188674	0.056937394	-0.066515664	-0.044837681	-0.019354045	0.010193295	0.002406272	0.08098809	-0.057604668	-0.095442191	-0.041717274	-0.039830067	0.026477548	0.046116015	0.10044598	0.048748816	0.176627029	0.13322179	-0.012035904	0.136607795	0.124623986	0.033205954	0.032809347	-0.128374695	-0.12627667	0.007561969	0.023223855
0.013129786	0.023592731	-0.114278101	-0.150588781	-0.128245754	-0.124418758	-0.011590381	-0.091230983	-0.062554734	NaN	0.065000151	-0.049282603	-0.093332943	0.069270002	-0.070726915	-0.098814443	-0.015137031	0.041352783	-0.103196026	0.023039411	-0.035720789	-0.126829348	0.138028301	0.034420663	0.04956123	0.098472382	0.017123502	0.147644378	0.038597091	0.106639313	0.131194474	0.171032702	0.101088552	0.217321523	0.097448137	0.094473652	-0.043425704	0.071895478	0.073038323	0.021163355	0.012918121	-0.02169035	0.105397535	-0.133685413	-0.067603161	0.052826898	-0.000216453	0.047157446	0.044422347	0.102732662	0.063915511
0.006496274	0.033704405	-0.130421663	-0.227494814	-0.139148492	-0.178023286	0.002521139	-0.103674228	0.017636412	0.065000151	NaN	-0.048818706	-0.107107452	0.059395455	-0.025421743	0.007196813	0.029664041	0.033261332	0.041822557	0.106608785	-0.018439665	-0.053559235	0.060210878	-0.017643717	0.051632521	0.050678114	0.010745425	0.11425097	0.022046595	0.09907019	0.101401844	0.22902082	0.096562267	0.201472897	0.120659614	0.107868312	0.056569452	0.054562146	0.062003045	0.005301696	-0.023069521	-0.104905116	0.054950216	-0.131900124	-0.026517215	0.111607481	0.045625404	0.068973919	0.030005746	0.039974491	0.002842213
-0.033345552	-0.063814156	-0.113327914	-0.229544312	0.038295724	0.009795985	-0.057836366	-0.073438182	-0.109921487	-0.049282603	-0.048818706	NaN	0.208775411	0.061285288	0.055941633	0.089809744	-0.077230229	-0.048756527	-0.138982219	-0.056816359	0.021386351	-0.008546112	0.043289445	-0.020490658	-0.046812379	-0.085450655	0.068414363	0.173966379	-0.029772135	-0.019134217	-0.020391728	5.96E-05	0.091932091	0.029899929	0.004015803	0.058150138	-0.123152888	-0.08134885	-0.151160104	-0.004019734	-0.140511186	-0.100271387	0.113381904	-0.23545976	-0.095114344	-0.017619606	-0.053321763	0.112934981	0.047996705	0.003784917	-0.032064644
-0.002564576	-0.04725378	0.005900026	-0.135038258	0.042953934	0.019844582	-0.137832089	-0.209483233	-0.107194599	-0.093332943	-0.107107452	0.208775411	NaN	0.03651758	0.043577364	0.067485389	-0.078031353	-0.109139155	-0.127723725	-0.025681246	-0.037600831	-0.067587267	0.073373153	-0.043724221	-0.125884227	-0.130886109	0.07590697	0.134823252	-0.038389815	-0.023694826	-0.097466759	0.037538096	0.071177427	0.083651545	0.036374973	1.33E-01	-0.059612435	-0.059079481	-0.145460784	-0.02843372	-0.079614242	-0.08015792	0.105525418	-0.193900935	-0.147863334	-0.014373702	-0.038556838	0.144390424	0.074811263	0.037247289	-0.0255542
-0.098719365	-0.128433922	-0.052368578	-0.132431655	-0.002516719	-0.073915056	-0.070204763	-0.160023448	0.006950511	0.069270002	0.059395455	0.061285288	0.03651758	NaN	0.081022115	0.125855919	0.006111152	0.015396472	-0.012521015	-0.037946469	0.023559861	0.029610173	0.099104406	-0.059871605	0.077297455	-0.028327402	-0.026125863	0.006115888	0.074945873	0.021171735	0.077505795	0.116908781	0.09798145	0.124086969	0.101797174	0.101137072	0.031280437	-0.12799389	-0.037665021	-0.084841528	-0.134565674	-0.106523473	-0.035790323	-0.115765473	-0.092343539	-0.047732918	-0.08434863	0.109137299	0.110842108	0.046243219	0.030999578
-0.026614031	0.029015082	-0.115863639	-0.134088864	-0.114847961	-0.053963808	-0.061542114	-0.02635372	0.009914222	-0.070726915	-0.025421743	0.055941633	0.043577364	0.081022115	NaN	0.11066072	-0.005203086	-0.010320744	0.054849389	0.071492612	-0.004801978	-0.005971214	-0.098093185	-0.018394517	0.011161437	0.028370225	-0.012042326	0.096637101	0.046810329	0.081672255	-0.010630901	0.034090269	-0.037474454	0.094007537	-0.050818095	0.086237179	0.035783965	-0.042158201	0.017707069	0.105530056	-0.045013023	0.099761019	0.053124235	-0.079887902	0.04099416	0.057708932	-0.063133157	0.111544414	0.077075598	-0.013081632	-0.023255464
-0.016516386	0.076451074	-0.097557521	-0.046182967	-0.018574781	-0.009150616	-0.035222745	-0.032473013	0.110611542	-0.098814443	0.007196813	0.089809744	0.067485389	0.125855919	0.11066072	NaN	0.006839574	0.030693911	0.048155282	0.103524656	0.018846139	0.026941207	0.038129294	0.065682318	0.054810527	0.136379007	0.061749504	0.105165609	0.102756554	0.070441288	-0.028576736	-0.013125599	-0.11967291	0.072835053	-0.097647832	0.082777018	0.144273491	0.016655627	0.02678247	0.120352576	-0.013285108	0.12667159	0.056345148	0.000450397	0.128305826	-0.015390257	-0.111193785	-0.013317989	0.038270923	-0.12961419	-0.138027566
-0.054516118	0.051994731	-0.108879282	0.041076237	-0.073574285	-0.012334629	0.01698155	0.024832399	0.090182626	-0.015137031	0.029664041	-0.077230229	-0.078031353	0.006111152	-0.005203086	0.006839574	NaN	0.048903555	-0.017263081	0.071612395	-0.024223795	-0.146133172	0.109430516	0.087680214	0.038288823	0.036591361	0.092336954	0.07567111	0.096717494	0.021311528	-0.124301416	-0.100574539	0.138076352	0.015256582	0.035354304	0.017373732	0.085897706	0.0136482	-0.041713542	0.013546744	0.150228198	-0.01891561	0.044760398	0.078863001	0.068605283	-0.131534277	-0.148940331	0.034449561	0.031429531	0.061948273	0.057070631
0.007011381	-0.059559904	-0.068143987	0.020236361	0.013189401	0.008207781	-0.008999133	-0.039989277	0.115326636	0.041352783	0.033261332	-0.048756527	-0.109139155	0.015396472	-0.010320744	0.030693911	0.048903555	NaN	-0.041025441	0.05995515	-0.012661773	-0.020762425	-0.026645944	-0.072515512	-0.011607165	0.030894811	-0.046680213	-0.039824935	0.050409206	0.018067602	-0.02106613	-0.116496543	0.024620636	0.04037931	0.047031979	0.01062866	0.169969049	0.094267518	0.047919183	0.131260793	0.082024548	-0.035317139	-0.060897908	0.003076361	0.071015251	-0.086290663	-0.062143509	-0.001315538	-0.038221025	-0.025990214	0.037273272
0.03223208	0.058312084	0.007124505	0.042498302	0.042471434	0.047156054	0.012406318	-0.0042605	-0.084393206	-0.103196026	0.041822557	-0.138982219	-0.127723725	-0.012521015	0.054849389	0.048155282	-0.017263081	-0.041025441	NaN	0.085276103	-0.075086857	-0.119511157	0.017349203	0.021995869	0.00132728	0.075055224	-0.003110732	0.020445336	0.062431364	0.079780573	0.000162575	0.060602272	0.139323781	0.120125006	0.006342158	0.054499191	-0.052021556	0.033421586	0.031045941	-0.056092167	0.044953676	0.002540402	0.047364581	-0.079810175	-0.058986832	-0.013764269	-0.05278244	-0.043355227	-0.050932718	0.103490305	0.117373243
0.073511047	0.019141777	0.044781401	0.016635976	0.005969032	0.026127966	-0.118820048	-0.120503017	0.057687327	0.023039411	0.106608785	-0.056816359	-0.025681246	-0.037946469	0.071492612	0.103524656	0.071612395	0.05995515	0.085276103	NaN	0.019556195	0.080808546	-0.007018348	-0.07944104	-0.083443166	-0.032434193	-0.158098092	-0.121962614	-0.026849303	-0.005966263	0.097910197	0.169032648	0.128320641	0.090694153	0.072823592	0.145402059	0.094608095	0.026707015	0.009033109	-0.154136914	-0.043339534	0.034485323	-0.082173335	-0.158536376	-0.011964523	-0.025176178	-0.084230057	-0.001932999	-0.030021747	-0.077614112	-0.113762116
0.005558539	-0.055594952	-0.01823134	-0.103599443	-0.033417429	-0.056445012	-0.016862646	-0.074280147	-1.85E-02	-0.035720789	-0.018439665	0.021386351	-0.037600831	0.023559861	-0.004801978	0.018846139	-0.024223795	-0.012661773	-0.075086857	0.019556195	NaN	0.055727873	-0.028071253	-0.086630494	-0.070440168	-0.034442152	-0.060188008	0.141562153	0.060515643	0.091682591	0.042494899	0.010352766	0.102094095	0.218516057	0.039333099	0.174222554	-0.004801575	-0.116873623	0.00366618	-0.069629764	-0.079262673	-0.01194114	-0.044209006	-0.155735498	-0.014617078	-0.067518235	-0.127671549	0.177633518	0.093881575	0.039010944	0.045256441
0.042599583	0.051065276	0.006560797	-0.030948307	-0.017078987	-0.024854874	-0.043340038	-0.024260612	0.083842442	-0.126829348	-0.053559235	-0.008546112	-0.067587267	0.029610173	-0.005971214	0.026941207	-0.146133172	-0.020762425	-0.119511157	0.080808546	0.055727873	NaN	-0.003785131	-0.06729722	-0.109273751	-0.05133507	0.018401509	0.099367941	0.074979393	0.104786174	0.001737726	0.021587392	0.041844527	0.145173911	-0.081556049	0.096371603	0.066732095	0.045542815	-0.031145204	0.114629599	-0.022896116	0.03664213	0.09344316	-0.096847304	0.018870883	-0.03813129	-0.070165751	0.104615816	0.071055556	-0.122096944	-0.077351151
-0.033389461	-0.078616754	-0.018639963	-0.071377022	-0.055174049	0.016064747	0.071361904	0.028442299	-0.066222009	0.138028301	0.060210878	0.043289445	0.073373153	0.099104406	-0.098093185	0.038129294	0.109430516	-0.026645944	0.017349203	-0.007018348	-0.028071253	-0.003785131	NaN	0.124703611	0.151249838	0.097634567	0.159857061	0.037612068	-0.117882698	-0.175090418	0.146737429	0.014508928	-0.09178115	-0.017134732	0.058347291	-0.11670008	-0.087612847	-0.043331947	0.150008818	0.061095936	0.042347371	0.02453242	0.060133835	0.030282031	-0.06213523	0.068511909	0.120246278	-0.031461463	0.032911192	0.006814058	0.078335978
-0.060876934	-0.045829645	0.02373468	-0.019000112	-0.027080278	0.058634741	0.114091402	0.044322808	-0.021798913	0.034420663	-0.017643717	-0.020490658	-0.043724221	-0.059871605	-0.018394517	0.065682318	0.087680214	-0.072515512	0.021995869	-0.07944104	-0.086630494	-0.06729722	0.124703611	NaN	0.110282292	0.043315622	0.176021379	0.024407958	-0.037681642	-0.091131394	0.067771813	-0.012535798	-0.019039964	-0.002940349	0.04987845	-0.076889848	-0.023175551	-0.074100707	0.065515507	-0.011067975	-0.026211398	-0.043596218	0.066388027	0.011283853	-0.071412285	0.064766995	0.08941619	-0.063710475	0.011380541	0.057991728	0.045715097
-0.094219802	-0.047738991	0.049525486	0.118290685	0.016390439	0.065601332	0.135140266	0.155181809	-0.040188674	0.04956123	0.051632521	-0.046812379	-0.125884227	0.077297455	0.011161437	0.054810527	0.038288823	-0.011607165	0.00132728	-0.083443166	-0.070440168	-0.109273751	0.151249838	0.110282292	NaN	0.037010543	0.165006051	0.083842725	0.058670428	-0.030046367	0.022297692	-0.057413776	-0.057802232	-0.079474632	0.002657516	-0.177410074	-0.109510447	-0.020503736	-0.007432375	-0.054079883	0.081393309	-0.0549806	0.210788865	0.141567156	-0.057420781	-0.077722308	-0.018627212	0.059527469	0.066573879	0.070418715	0.101803691
-0.046965349	-0.026813551	0.052022443	0.072304498	-0.034262322	-0.068724775	0.086769682	0.063051291	0.056937394	0.098472382	0.050678114	-0.085450655	-0.130886109	-0.028327402	0.028370225	0.136379007	0.036591361	0.030894811	0.075055224	-0.032434193	-0.034442152	-0.05133507	0.097634567	0.043315622	0.037010543	NaN	0.096827791	-0.008223393	0.116075501	0.036527812	-0.025480961	-0.060466647	-0.074031799	-0.133964361	-0.025990501	-0.160872925	0.04222148	-0.033844041	0.03024004	-0.085212856	-0.016165899	-0.043561066	0.086202194	0.065708537	0.028689169	-0.020696689	0.050005237	-0.000484784	0.025920843	0.123667701	0.103392487
-0.007015203	0.002861121	-0.038782803	-0.104656065	-0.049256954	0.112780991	0.004484064	-0.017255237	-0.066515664	0.017123502	0.010745425	0.068414363	0.07590697	-0.026125863	-0.012042326	0.061749504	0.092336954	-0.046680213	-0.003110732	-0.158098092	-0.060188008	0.018401509	0.159857061	0.176021379	0.165006051	0.096827791	NaN	0.049274819	-0.080024545	-0.128138537	0.069544083	-0.029178163	-0.120844511	-0.038651862	-0.032662143	-0.106323729	-0.08751853	-0.130584031	0.190632926	-0.117093074	0.011131752	-0.007659878	0.077720918	-0.010041603	-0.091938831	0.029033241	-0.006633568	-0.084655653	-0.009916962	0.018606713	-0.029663053
-0.016909928	-0.053215828	-0.040689893	-0.128397174	-0.026945449	0.046158314	0.042022173	0.002772316	-0.044837681	0.147644378	0.11425097	0.173966379	0.134823252	0.006115888	0.096637101	0.105165609	0.07567111	-0.039824935	0.020445336	-0.121962614	0.141562153	0.099367941	0.037612068	0.024407958	0.083842725	-0.008223393	0.049274819	NaN	-0.091599488	-0.108203095	0.077174178	0.025569498	-0.046316308	-0.04368897	-0.056054491	-0.138929499	-0.063025214	-0.150813676	0.044867524	-0.146359343	-0.135575335	0.00623301	0.012754834	-0.029159476	-0.136181263	-0.005077838	0.025443418	-0.054838121	0.08257008	0.029912564	0.007914875
-0.034563138	-0.043432833	-0.115196475	-0.076092959	-0.131725125	-0.029620323	-0.076760958	-0.065054884	-0.019354045	0.038597091	0.022046595	-0.029772135	-0.038389815	0.074945873	0.046810329	0.102756554	0.096717494	0.050409206	0.062431364	-0.026849303	0.060515643	0.074979393	-0.117882698	-0.037681642	0.058670428	0.116075501	-0.080024545	-0.091599488	NaN	0.032843938	0.053309304	0.04562542	0.011111045	-0.035875327	0.068568681	0.048469925	0.055894613	-0.026026313	0.21724112	-0.030601342	-0.059319339	0.054737887	-0.028647454	-0.042300784	-0.012357203	-0.010679565	-0.034589555	-0.076711847	-0.061719071	-0.022652995	0.013077722
-0.067657116	-0.043747154	-0.14658427	-0.095367297	-0.147808616	-0.030740627	-0.110083442	-0.126125831	0.010193295	0.106639313	0.09907019	-0.019134217	-0.023694826	0.021171735	0.081672255	0.070441288	0.021311528	0.018067602	0.079780573	-0.005966263	0.091682591	0.104786174	-0.175090418	-0.091131394	-0.030046367	0.036527812	-0.128138537	-0.108203095	0.032843938	NaN	0.029384159	0.033450023	0.029995205	-0.002637734	0.05795682	0.036905679	0.0757499	-0.053719419	0.159307963	-0.01250155	-0.084181053	0.047464877	-0.085797128	0.008339805	-0.008646747	0.01065977	-0.022163709	-0.123410806	-0.056812537	0.037574928	0.070348848
-0.096715371	-0.054481416	-0.073009574	0.006119528	0.002561472	0.04756591	0.005834833	-0.00754612	0.002406272	0.131194474	0.101401844	-0.020391728	-0.097466759	0.077505795	-0.010630901	-0.028576736	-0.124301416	-0.02106613	0.000162575	0.097910197	0.042494899	0.001737726	0.146737429	0.067771813	0.022297692	-0.025480961	0.069544083	0.077174178	0.053309304	0.029384159	NaN	0.081396985	0.165942745	0.15161363	0.156408943	0.105254688	-0.000523838	-0.073974781	-0.044709281	0.014446314	0.033336629	-0.009867116	0.099066915	-0.021745231	-0.017962943	-0.251792887	-0.263034597	0.178161829	0.10166525	0.018869469	0.022915733
-0.142696738	-0.2114523	-0.060118927	0.015928814	-0.112248394	-0.04360963	-0.054411245	-0.1377317	0.08098809	0.171032702	0.22902082	5.96E-05	0.037538096	0.116908781	0.034090269	-0.013125599	-0.100574539	-0.116496543	0.060602272	0.169032648	0.010352766	0.021587392	0.014508928	-0.012535798	-0.057413776	-0.060466647	-0.029178163	0.025569498	0.04562542	0.033450023	0.081396985	NaN	-0.029579511	-0.04090369	0.128188032	-0.008310182	0.083618002	-0.093753931	0.092171086	0.028847025	0.082446903	0.008925116	-0.01389402	0.034918371	0.104693654	-0.125479226	-0.117519347	0.007608376	-0.075055452	-0.07794286	-0.089862414
0.066953074	-0.085035877	0.034733187	0.003748364	-0.001487893	0.04269966	-0.058942329	0.003498842	-0.057604668	0.101088552	0.096562267	0.091932091	0.071177427	0.09798145	-0.037474454	-0.11967291	0.138076352	0.024620636	0.139323781	0.128320641	0.102094095	0.041844527	-0.09178115	-0.019039964	-0.057802232	-0.074031799	-0.120844511	-0.046316308	0.011111045	0.029995205	0.165942745	-0.029579511	NaN	0.065776723	0.066050895	0.064587885	-0.052798759	-0.062421313	0.100621509	-0.019524841	0.030147196	0.116671925	0.075470512	0.012138705	-0.00120504	-0.14305405	-0.138723867	0.098852673	0.105955963	-0.042755773	-0.091394485
0.023679233	-0.135979787	0.073269862	0.000164959	0.045049728	0.083796966	0.051308639	0.05561028	-0.095442191	0.217321523	0.201472897	0.029899929	0.083651545	0.124086969	0.094007537	0.072835053	0.015256582	0.04037931	0.120125006	0.090694153	0.218516057	0.145173911	-0.017134732	-0.002940349	-0.079474632	-0.133964361	-0.038651862	-0.04368897	-0.035875327	-0.002637734	0.15161363	-0.04090369	0.065776723	NaN	-0.054576426	-0.013330526	-0.07269475	-0.143659916	0.065869529	0.0351857	0.014441093	0.004361555	-0.072663931	-0.073455667	-0.057531633	-0.154780378	-0.09449828	0.065375335	-0.028188847	-0.044422938	-0.04056543
-0.010844779	0.001243317	0.058842492	0.006684067	-0.060181	0.00169155	0.009748345	-0.062867201	-0.041717274	0.097448137	0.120659614	0.004015803	0.036374973	0.101797174	-0.050818095	-0.097647832	0.035354304	0.047031979	0.006342158	0.072823592	0.039333099	-0.081556049	0.058347291	0.04987845	0.002657516	-0.025990501	-0.032662143	-0.056054491	0.068568681	0.05795682	0.156408943	0.128188032	0.066050895	-0.054576426	NaN	0.07672353	-0.014021056	-0.053335958	0.072768437	-0.181179748	0.034968782	0.005803681	0.01116448	-0.124953635	-0.053651	-0.105202476	-0.086615623	0.035201961	-0.137280858	-0.008829947	-0.021808317
-0.0555536	-0.13017082	0.094229247	0.056904491	0.054730289	0.132689108	-0.058792315	-0.025987634	-0.039830067	0.094473652	0.107868312	0.058150138	0.133473574	0.101137072	0.086237179	0.082777018	0.017373732	0.01062866	0.054499191	0.145402059	0.174222554	0.096371603	-0.11670008	-0.076889848	-0.177410074	-0.160872925	-0.106323729	-0.138929499	0.048469925	0.036905679	0.105254688	-0.008310182	0.064587885	-0.013330526	0.07672353	NaN	-0.040012341	-0.1006256	-0.005451143	-0.023029614	-0.019599222	0.054118383	-0.045214141	-0.075970052	-0.021964814	-0.124050424	-0.074684896	0.084616711	-0.052988842	-0.119393752	-0.113824455
0.053865132	-0.010573098	0.007339237	0.128349407	0.04021975	0.079650264	-0.057044736	-0.112526437	0.026477548	-0.043425704	0.056569452	-0.123152888	-0.059612435	0.031280437	0.035783965	0.144273491	0.085897706	0.169969049	-0.052021556	0.094608095	-0.004801575	0.066732095	-0.087612847	-0.023175551	-0.109510447	0.04222148	-0.08751853	-0.063025214	0.055894613	0.0757499	-0.000523838	0.083618002	-0.052798759	-0.07269475	-0.014021056	-0.040012341	NaN	0.034969913	0.086377087	0.052185497	0.166133549	0.136013163	-0.017557652	0.143838443	0.105021145	-0.068424961	-0.085257566	-0.15587061	-0.133862305	0.007008377	-0.007504139
-0.044353859	0.003478751	0.020540892	0.124177117	0.010955853	0.070301995	0.150069737	-0.037991576	0.046116015	0.071895478	0.054562146	-0.08134885	-0.059079481	-0.12799389	-0.042158201	0.016655627	0.0136482	0.094267518	0.033421586	0.026707015	-0.116873623	0.045542815	-0.043331947	-0.074100707	-0.020503736	-0.033844041	-0.130584031	-0.150813676	-0.026026313	-0.053719419	-0.073974781	-0.093753931	-0.062421313	-0.143659916	-0.053335958	-0.1006256	0.034969913	NaN	0.062738646	0.045479306	0.098041356	-0.033511663	-0.12241891	0.137587964	-0.008408889	-0.098931192	-0.11145061	-0.024454544	-0.121117436	-0.006975265	-0.014175868
0.049924018	0.050716869	0.144944371	0.150445256	0.091748895	-0.020205437	0.057502991	-0.046939211	0.10044598	0.073038323	0.062003045	-0.151160104	-0.145460784	-0.037665021	0.017707069	0.02678247	-0.041713542	0.047919183	0.031045941	0.009033109	0.00366618	-0.031145204	0.150008818	0.065515507	-0.007432375	0.03024004	0.190632926	0.044867524	0.21724112	0.159307963	-0.044709281	0.092171086	0.100621509	0.065869529	0.072768437	-0.005451143	0.086377087	0.062738646	NaN	-0.067695274	0.126191804	-0.100922024	-0.018308346	0.022778186	0.00666385	-0.125741537	-0.140829455	0.010854781	0.029618641	-0.043815336	-0.119914998
0.078791344	-0.013831141	0.066079599	0.05830874	0.036659695	0.074856085	0.041310408	-0.024549321	0.048748816	0.021163355	0.005301696	-0.004019734	-0.02843372	-0.084841528	0.105530056	0.120352576	0.013546744	0.131260793	-0.056092167	-0.154136914	-0.069629764	0.114629599	0.061095936	-0.011067975	-0.054079883	-0.085212856	-0.117093074	-0.146359343	-0.030601342	-0.01250155	0.014446314	0.028847025	-0.019524841	0.0351857	-0.181179748	-0.023029614	0.052185497	0.045479306	-0.067695274	NaN	0.034563009	-0.067537222	-0.05062034	-0.038962068	-0.047041771	0.003772998	0.017556594	-0.057321207	-0.018043169	-0.074239823	-0.064804517
0.177235806	0.212906957	0.094177764	0.150122684	0.100938738	0.03334437	0.145371496	0.063363728	0.176627029	0.012918121	-0.023069521	-0.140511186	-0.079614242	-0.134565674	-0.045013023	-0.013285108	0.150228198	0.082024548	0.044953676	-0.043339534	-0.079262673	-0.022896116	0.042347371	-0.026211398	0.081393309	-0.016165899	0.011131752	-0.135575335	-0.059319339	-0.084181053	0.033336629	0.082446903	0.030147196	0.014441093	0.034968782	-0.019599222	0.166133549	0.098041356	0.126191804	0.034563009	NaN	-0.039087385	-0.049879761	0.086931721	0.050648823	0.016741234	0.010297235	-0.045171771	-0.078177896	-0.033842712	-0.113280305
-0.011635962	-0.014102742	0.13501936	0.057403543	0.022184934	0.056965203	0.043092614	-0.010634392	0.13322179	-0.02169035	-0.104905116	-0.100271387	-0.08015792	-0.106523473	0.099761019	0.12667159	-0.01891561	-0.035317139	0.002540402	0.034485323	-0.01194114	0.03664213	0.02453242	-0.043596218	-0.0549806	-0.043561066	-0.007659878	0.00623301	0.054737887	0.047464877	-0.009867116	0.008925116	0.116671925	0.004361555	0.005803681	0.054118383	0.136013163	-0.033511663	-0.100922024	-0.067537222	-0.039087385	NaN	-0.072972556	-0.065234792	0.034323985	0.006231134	0.029736087	0.039414269	-0.068277046	-0.039879183	-0.030292561
-0.084542229	-0.06609186	0.029358968	-0.078831105	0.008787797	-0.040638908	0.134282218	0.077775972	-0.012035904	0.105397535	0.054950216	0.113381904	0.105525418	-0.035790323	0.053124235	0.056345148	0.044760398	-0.060897908	0.047364581	-0.082173335	-0.044209006	0.09344316	0.060133835	0.066388027	0.210788865	0.086202194	0.077720918	0.012754834	-0.028647454	-0.085797128	0.099066915	-0.01389402	0.075470512	-0.072663931	0.01116448	-0.045214141	-0.017557652	-0.12241891	-0.018308346	-0.05062034	-0.049879761	-0.072972556	NaN	0.00389993	-0.087819617	-0.004721554	-0.033305557	-0.069413412	0.00683119	-0.031634262	-0.049944729
0.019512628	0.142170281	0.001915112	-0.073259473	-0.074321486	-0.071202535	0.030272295	0.000304305	0.136607795	-0.133685413	-0.131900124	-0.23545976	-0.193900935	-0.115765473	-0.079887902	0.000450397	0.078863001	0.003076361	-0.079810175	-0.158536376	-0.155735498	-0.096847304	0.030282031	0.011283853	0.141567156	0.065708537	-0.010041603	-0.029159476	-0.042300784	0.008339805	-0.021745231	0.034918371	0.012138705	-0.073455667	-0.124953635	-0.075970052	0.143838443	0.137587964	0.022778186	-0.038962068	0.086931721	-0.065234792	0.00389993	NaN	0.079620913	0.200627583	0.196009252	-0.100756859	-0.033502346	0.069813726	0.04457319
0.067641112	0.00748401	0.094605363	0.137081815	0.038474372	0.098068927	-0.006703865	-0.068023625	0.124623986	-0.067603161	-0.026517215	-0.095114344	-0.147863334	-0.092343539	0.04099416	0.128305826	0.068605283	0.071015251	-0.058986832	-0.011964523	-0.014617078	0.018870883	-0.06213523	-0.071412285	-0.057420781	0.028689169	-0.091938831	-0.136181263	-0.012357203	-0.008646747	-0.017962943	0.104693654	-0.00120504	-0.057531633	-0.053651	-0.021964814	0.105021145	-0.008408889	0.00666385	-0.047041771	0.050648823	0.034323985	-0.087819617	0.079620913	NaN	0.092258309	0.096933926	-0.140913421	-0.066376558	0.007364528	-0.018847954
-0.143662445	-0.129557634	0.031127393	-0.003549012	0.018694065	-0.039106213	-0.018589855	-0.032967714	0.033205954	0.052826898	0.111607481	-0.017619606	-0.014373702	-0.047732918	0.057708932	-0.015390257	-0.131534277	-0.086290663	-0.013764269	-0.025176178	-0.067518235	-0.03813129	0.068511909	0.064766995	-0.077722308	-0.020696689	0.029033241	-0.005077838	-0.010679565	0.01065977	-0.251792887	-0.125479226	-0.14305405	-0.154780378	-0.105202476	-0.124050424	-0.068424961	-0.098931192	-0.125741537	0.003772998	0.016741234	0.006231134	-0.004721554	0.200627583	0.092258309	NaN	-0.009907042	0.076615997	0.082373387	0.077287254	0.041133458
-0.133078844	-0.145124542	-0.011149325	-0.02480174	0.018217867	-0.059664911	-0.033044153	-0.033632783	0.032809347	-0.000216453	0.045625404	-0.053321763	-0.038556838	-0.08434863	-0.063133157	-0.111193785	-0.148940331	-0.062143509	-0.05278244	-0.084230057	-0.127671549	-0.070165751	0.120246278	0.08941619	-0.018627212	0.050005237	-0.006633568	0.025443418	-0.034589555	-0.022163709	-0.263034597	-0.117519347	-0.138723867	-0.09449828	-0.086615623	-0.074684896	-0.085257566	-0.11145061	-0.140829455	0.017556594	0.010297235	0.029736087	-0.033305557	0.196009252	0.096933926	-0.009907042	NaN	0.101940462	0.089974194	0.096797209	0.062738198
-0.067904701	-0.150526998	0.002695878	-0.121214648	-0.03175669	0.018752551	-0.027198664	0.010276659	-0.128374695	0.047157446	0.068973919	0.112934981	0.144390424	0.109137299	0.111544414	-0.013317989	0.034449561	-0.001315538	-0.043355227	-0.001932999	0.177633518	0.104615816	-0.031461463	-0.063710475	0.059527469	-0.000484784	-0.084655653	-0.054838121	-0.076711847	-0.123410806	0.178161829	0.007608376	0.098852673	0.065375335	0.035201961	0.084616711	-0.15587061	-0.024454544	0.010854781	-0.057321207	-0.045171771	0.039414269	-0.069413412	-0.100756859	-0.140913421	0.076615997	0.101940462	NaN	0.060900603	-0.083096867	-0.048724451
-0.097242793	-0.134536184	0.008752149	-0.094453081	-0.06997855	0.004261628	0.051159513	0.117616588	-0.12627667	0.044422347	0.030005746	0.047996705	0.074811263	0.110842108	0.077075598	0.038270923	0.031429531	-0.038221025	-0.050932718	-0.030021747	0.093881575	0.071055556	0.032911192	0.011380541	0.066573879	0.025920843	-0.009916962	0.08257008	-0.061719071	-0.056812537	0.10166525	-0.075055452	0.105955963	-0.028188847	-0.137280858	-0.052988842	-0.133862305	-0.121117436	0.029618641	-0.018043169	-0.078177896	-0.068277046	0.00683119	-0.033502346	-0.066376558	0.082373387	0.089974194	0.060900603	NaN	-0.065784548	-0.039745031
-0.052863049	-0.164733925	-0.069653952	-0.176856034	-0.143361434	-0.256376708	0.041053629	0.019892648	0.007561969	0.102732662	0.039974491	0.003784917	0.037247289	0.046243219	-0.013081632	-0.12961419	0.061948273	-0.025990214	0.103490305	-0.077614112	0.039010944	-0.122096944	0.006814058	0.057991728	0.070418715	0.123667701	0.018606713	0.029912564	-0.022652995	0.037574928	0.018869469	-0.07794286	-0.042755773	-0.044422938	-0.008829947	-0.119393752	0.007008377	-0.006975265	-0.043815336	-0.074239823	-0.033842712	-0.039879183	-0.031634262	0.069813726	0.007364528	0.077287254	0.096797209	-0.083096867	-0.065784548	NaN	0.08880426
0.010002757	-0.147533138	-0.092077819	-0.225954128	-0.104465263	-0.236121364	0.084521806	0.021751506	0.023223855	0.063915511	0.002842213	-0.032064644	-0.0255542	0.030999578	-0.023255464	-0.138027566	0.057070631	0.037273272	0.117373243	-0.113762116	0.045256441	-0.077351151	0.078335978	0.045715097	0.101803691	0.103392487	-0.029663053	0.007914875	0.013077722	0.070348848	0.022915733	-0.089862414	-0.091394485	-0.04056543	-0.021808317	-0.113824455	-0.007504139	-0.014175868	-0.119914998	-0.064804517	-0.113280305	-0.030292561	-0.049944729	0.04457319	-0.018847954	0.041133458	0.062738198	-0.048724451	-0.039745031	0.08880426	NaN]

%set up 'RowLabels' and 'ColumnLabels' as a cell array of ROI labels
%you can use "concatenate" function in excel to create a new column and
%using the concatenate function to put together a ' with the roi string and
%another ' with something like: =concatenate("'",cell_with_roi_string,"'")


%paste to matlab to make cell array
% example:


%row_labels={'smith_dmn_c4 smith_fp_c3 smith_lexec_c10 smith_primvisual_c2 smith_rexec_c9 smith_sal_c8'}

%col_labels={'smith_dmn_c4 smith_fp_c3 smith_lexec_c10 smith_primvisual_c2 smith_rexec_c9 smith_sal_c8'}

%%%%%%%%%

% row_labels={'pcc'	'mpfc' 'Lhipp_vandjik'	'Rhipp_vandjik'	'smith_dmn_c4' 'mtl_subsystem'}
% 
% col_labels={'pcc'	'mpfc' 'Lhipp_vandjik'	'Rhipp_vandjik'	'smith_dmn_c4' 'mtl_subsystem'}
% 

%make a heatmap

hmo=HeatMap(corrmat,'RowLabels',row_labels,'ColumnLabels',col_labels,'Colormap',colormap, 'NaNColor', [0 0 0], 'colorbar', true, 'GridLines', ':')
addTitle(hmo,'act/pass diff', 'FontSize', 20)
%plot(hmo)

    
%hmo=HeatMap(corrmat_old,'RowLabels',row_labels,'ColumnLabels',col_labels,'Colormap',jet)
%addTitle(hmo,'Chord Learning Sample: N=12 old adults', 'FontSize', 14)



%%%%%%%%%  Evaluate clustering for an ROI by ROI matrix %%%%%%%%
%AH2010 paper used average linkage function on the z-transformed
%correlation matrix

%dendrogram/linkage should give same thing if on corrmat or dissim mat

dissim=1.-corrmat
Z1=linkage(dissim,'average','correlation')
dendrogram(Z1,'Labels',row_labels)

Z2=linkage(corrmat,'average','correlation')
dendrogram(Z2,'Labels',row_labels)

%Z2=linkage(corrmat_old,'average','correlation')
%dendrogram(Z2,'Labels',row_labels)
