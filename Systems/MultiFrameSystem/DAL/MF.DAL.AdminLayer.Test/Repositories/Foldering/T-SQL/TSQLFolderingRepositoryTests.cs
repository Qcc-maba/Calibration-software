using Microsoft.VisualStudio.TestTools.UnitTesting;
using Maba.Hydra2.Systems.MF.DAL.AdminLayer.Repositories.Foldering.TSQL;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using Maba.Hydra2.Systems.MF.DAL.AdminLayer.Models;
using System.Diagnostics;

namespace Maba.Hydra2.Systems.MF.DAL.AdminLayer.Repositories.Foldering.TSQL.Test
{
    [TestClass()]
    public class MF_DAL_Foldering_TSQLFolderingRepositoryTests
    {
        #region members

        private TSQLFolderingRepository rep = null;
        private Device.TSQL.Test.MF_AdminLayer_Device__TSQLDeviceRepositoryTests deviceRep = null;
        private Models.AccountUser _user;
        private Random rand = new Random();
        private int _DeviceIndex = 0;

        private List<Tuple<long, Models.MainSite>> _CreatedSites = new List<Tuple<long, Models.MainSite>>();
        private List<Tuple<long, Models.MainSite>> _CreatedProjects = new List<Tuple<long, Models.MainSite>>();

        #endregion

        #region ctor

        public MF_DAL_Foldering_TSQLFolderingRepositoryTests()
        {
            rep = new TSQLFolderingRepository();
        }

        #endregion

        #region Init & Clean

        [TestInitialize]
        public void Init()
        {
            GeneralHelper.Init();

            _user = GeneralHelper.CreateTesterUser();
            _CreatedSites.Clear();
            _CreatedProjects.Clear();

            deviceRep = new Device.TSQL.Test.MF_AdminLayer_Device__TSQLDeviceRepositoryTests();
            deviceRep._user = this._user;

            _DeviceIndex = 0;
        }

        [TestCleanup]
        public void Clean()
        {
            foreach (var s in _CreatedProjects)
            {
                Assert.IsTrue(rep.DeleteProject(s.Item2.SiteID, s.Item1));
            }

            foreach (var s in _CreatedSites.Where(s => !s.Item2.ParentSiteID.HasValue))
            {
                Assert.IsNull(rep.GetSite(s.Item2.SiteID));
            }

            GeneralHelper.Clean();

            deviceRep.Clean();
            deviceRep = null;
        }

        #endregion

        #region private methods

        private void TestFilterSite_Recursivly(treeNode2TestOnly t)
        {
            var tree = rep.GetTree(_user.UserID, 1, 100, t.Site.SiteID);
            Assert.IsNotNull(tree);
            Assert.AreEqual(tree.TotalProjects, 1);

            if (!t.Site.ParentSiteID.HasValue)
            {
                //for filtering by projectID we expect to get only one project in result
                Assert.AreEqual(tree.CurrentPageItems.Count(c => c.ParentSiteID == null), 1);
            }

            var filteredSite = tree.CurrentPageItems.FirstOrDefault(c => c.SiteID == t.Site.SiteID);
            Assert.IsNotNull(filteredSite);

            //test the result contains exactly the expected sites and projects
            var dropped = new List<Models.TreeNode>();
            for (int i = 0; i < tree.CurrentPageItems.Length; i++)
            {
                if (t.Found(tree.CurrentPageItems[i]))
                {
                    dropped.Add(tree.CurrentPageItems[i]);
                    tree.CurrentPageItems[i] = null;
                }
            }

            //make sure all items from db were cached by the local
            Assert.IsTrue(tree.CurrentPageItems.All(c => c == null));

            if (t.Children.Count > 0)
            {
                foreach (var c in t.Children)
                {
                    TestFilterSite_Recursivly(c);
                }
            }
        }

        private Models.MainSite _CreateSiteObj(int num = 0, long? parentSiteID = null, long? userID = null)
        {
            var _site = new Models.MainSite()
            {
                Name = parentSiteID.HasValue ? $"Site-{rand.Next(50, 50000)}" : $"New Project::{ rand.Next(10, 1000) }",
                ParentSiteID = parentSiteID,
                MapCenter_Zoom = num % 2 == 0 ? null : (byte?)rand.Next(1, 10),
                MapCenter_AutoBounds = rand.Next(1, 10) % 2 == 0,
                MapCenter_Latitude = $"{rand.Next(1000, 9999) / 10m}",
                MapCenter_Longitude = $"{rand.Next(1000, 9999) / 10m}",
                MapCenter_Mode = string.Concat((char)('A' + rand.Next(0, 'Z' - 'A'))),
            };

            if (parentSiteID.HasValue)
            {
                rep.AddSite(userID ?? _user.UserID, _site);

                _CreatedSites.Add(new Tuple<long, MainSite>(userID ?? _user.UserID, _site));

                //test get
                var sameSite = rep.GetSite(_site.SiteID);
                Assert.IsNotNull(sameSite);
                Assert.AreEqual(sameSite.SiteID, _site.SiteID);

                CompareSites(sameSite, _site);
            }
            else
            {
                rep.AddProject(_site, userID ?? _user.UserID);

                _CreatedProjects.Add(new Tuple<long, MainSite>(userID ?? _user.UserID, _site));

                //test get
                var sameProject = rep.GetProject(_site.SiteID);
                Assert.IsNotNull(sameProject);
                Assert.AreEqual(sameProject.SiteID, _site.SiteID);

                CompareSites(sameProject, _site);
            }

            Assert.IsTrue(_site.SiteID >= 0);

            return _site;
        }

        private void CompareSites(Models.MainSite s1, Models.MainSite s2)
        {
            Assert.AreNotEqual(s1.GetHashCode(), s2.GetHashCode());

            Assert.AreEqual(s1.Name, s2.Name);
            Assert.AreEqual(s1.SiteID, s2.SiteID);
            Assert.AreEqual(s1.MapCenter_AutoBounds, s2.MapCenter_AutoBounds);
            Assert.AreEqual(s1.MapCenter_Latitude, s2.MapCenter_Latitude);
            Assert.AreEqual(s1.MapCenter_Longitude, s2.MapCenter_Longitude);
            Assert.AreEqual(s1.MapCenter_Mode, s2.MapCenter_Mode);
            Assert.AreEqual(s1.MapCenter_Zoom, s2.MapCenter_Zoom);
            Assert.AreEqual(s1.ParentSiteID, s2.ParentSiteID);
            Assert.AreEqual(s1.WeatherAlgorithmID, s2.WeatherAlgorithmID);

        }

        private void _CreateDevices4Site(long siteID, int totalDevices)
        {
            if (totalDevices == 0)
                return;

            for (int deviceIndex = 0; deviceIndex < totalDevices; deviceIndex++)
            {
                Assert.IsNotNull(deviceRep._GetDevice(_DeviceIndex++, siteID, true));
            }
        }

        private treeNode2TestOnly[] _CreateTree(int totalProjects = 10, int maxlevel = 3, int attachDevices = 0, long? userID = null)
        {
            var _projects = new List<treeNode2TestOnly>();

            for (int i = 0; i < totalProjects; i++)
            {
                _projects.Add(new treeNode2TestOnly(_CreateSiteObj(i, null, userID)));
            }

            //for each project - create site
            for (int i = 0; i < _projects.Count; i++)
            {
                _CreateDevices4Site(_projects[i].Site.SiteID, attachDevices);

                //1st site for project
                var s1 = new treeNode2TestOnly(_CreateSiteObj(0, _projects[i].Site.SiteID, userID));
                _CreateDevices4Site(s1.Site.SiteID, attachDevices);
                _projects[i].Children.Add(s1);

                //2nd site for project
                var s2 = new treeNode2TestOnly(_CreateSiteObj(0, _projects[i].Site.SiteID, userID));
                _CreateDevices4Site(s2.Site.SiteID, attachDevices);
                _projects[i].Children.Add(s2);
                for (int innerIndex = 0; innerIndex < 2; innerIndex++)
                {
                    var s2_x = new treeNode2TestOnly(_CreateSiteObj(0, s2.Site.SiteID, userID));
                    s2.Children.Add(s2_x);
                    _CreateDevices4Site(s2_x.Site.SiteID, attachDevices);
                }

                //last site for project
                treeNode2TestOnly lastNode = new treeNode2TestOnly(_CreateSiteObj(0, _projects[i].Site.SiteID, userID));
                _projects[i].Children.Add(lastNode);
                _CreateDevices4Site(lastNode.Site.SiteID, attachDevices);

                for (int l = 0; l < maxlevel; l++)
                {
                    var lastNode_x = new treeNode2TestOnly(_CreateSiteObj(0, lastNode.Site.SiteID, userID));
                    lastNode.Children.Add(lastNode_x);
                    _CreateDevices4Site(lastNode_x.Site.SiteID, attachDevices);

                    lastNode = lastNode_x;
                }

            }

            return _projects.ToArray();
        }

        class treeNode2TestOnly
        {
            public Models.MainSite Site { get; set; }
            public List<treeNode2TestOnly> Children { get; set; }

            public treeNode2TestOnly(Models.MainSite s)
            {
                Site = s;
                Children = new List<treeNode2TestOnly>();
            }

            public int CountNodes()
            {
                return 1 + Children.Sum(c => c.CountNodes());
            }

            public bool Found(TreeNode user2Site)
            {
                if (this.Site.SiteID == user2Site.SiteID)
                {
                    return true;
                }

                if (this.Children.Any(c => c.Found(user2Site)))
                {
                    return true;
                }

                return false;
            }

            public IEnumerable<Tuple<int, treeNode2TestOnly>> Select(int level = 1, bool includeSelf = true)
            {
                if (includeSelf)
                {
                    yield return new Tuple<int, treeNode2TestOnly>(level, this);
                }

                foreach (var c in Children)
                {
                    foreach (var item in c.Select(level + 1))
                    {
                        yield return item;
                    }
                }
            }

            public override string ToString()
            {
                if (Site.ParentSiteID.HasValue)
                {
                    return $"S-{Site.SiteID}::{Site.Name}";

                }
                else
                {
                    return $"P-{Site.SiteID}::{Site.Name}";
                }
            }
        }

        #endregion


        [TestMethod()]
        public void Session_Test()
        {
            Assert.Fail("Implement Session tests");
        }

        [TestMethod()]
        public void GetTree_Test()
        {
            int totalProjects = 10;
            var _projects = _CreateTree(totalProjects);

            int totalTreeNodes = _projects.Sum(c => c.CountNodes());
            Debug.WriteLine("GetTree_Test :: Total nodes in tested tree={0}, Total Projects={1}", totalTreeNodes, totalProjects);


            int pageSize = 2;
            int pageNumber = 1;

            #region test paging

            //cases :: 
            //  1. all pages
            //  2. single page
            //  3. invalid page

            //we are testing variety of pageSize. Includes a case of pageSize which bigger than total projects.
            for (pageSize = 1; pageSize <= totalProjects + 1; pageSize++)
            {
                int totalPages = (totalProjects / pageSize) + (totalProjects % pageSize == 0 ? 0 : 1);
                //we are testing all cases for valid pageNumber, and another invalid pageNumber (=totalPages+1)
                for (pageNumber = 1; pageNumber <= (totalPages + 1); pageNumber++)
                {
                    var tree = rep.GetTree(_user.UserID, pageNumber, pageSize, null, null);

                    Assert.IsNotNull(tree);
                    Assert.AreEqual(tree.TotalProjects, totalProjects);

                    //compare with local expected paged result
                    var localPagedResponse = _projects
                                        .OrderBy(p => p.Site.Name)
                                        .Skip((pageNumber - 1) * pageSize)
                                        .Take(pageSize)
                                        .ToArray();

                    //test count projects in this page
                    Assert.AreEqual(localPagedResponse.Length, Math.Min(totalProjects, pageNumber * pageSize) - Math.Min(totalProjects, (pageNumber - 1) * pageSize));
                    //test count total items (counting recursively)
                    Assert.AreEqual(localPagedResponse.Sum(l => l.CountNodes()), tree.CurrentPageItems.Length);

                    //test the result contains exactly the expected sites and projects
                    var dropped = new List<Models.TreeNode>();
                    for (int i = 0; i < tree.CurrentPageItems.Length; i++)
                    {
                        if (localPagedResponse.Any(l => l.Found(tree.CurrentPageItems[i])))
                        {
                            dropped.Add(tree.CurrentPageItems[i]);
                            tree.CurrentPageItems[i] = null;
                        }
                    }

                    //make sure all items from db were cached by the local
                    Assert.IsTrue(tree.CurrentPageItems.All(t => t == null));

                }
            }

            #endregion

            #region search

            //cases :: 
            //  1. search for valid project name
            //  2. search with result of all projects
            //  3. search with result of all sites
            //  4. test search with lower and capital (search should NOT Case-Sensitive)
            //  5. search for no-exists project (name "XXXX")

            var name2Search = new string[] {
                        //invalid
                        "XXXX",
                        //many results
                        "1",
                        //all projects.
                        "Project",
                        "project",
                        //All sites (with Capital)
                        "Site",
                        //All sites (lower case)
                        "site",
                        _projects[rand.Next(0,totalProjects-1)].Site.Name,
                        _projects[rand.Next(0,totalProjects-1)].Site.Name,
                        _projects[rand.Next(0,totalProjects-1)].Site.Name,
                        _projects[rand.Next(0,totalProjects-1)].Site.Name,
            };

            pageNumber = 1;
            pageSize = 2;
            foreach (var searchText in name2Search)
            {
                var tree = rep.GetTree(_user.UserID, pageNumber, pageSize, null, null, searchText);
                Assert.IsNotNull(tree);
                if (searchText.ToLower() == "project")
                {
                    //for expected result as all projects
                    Assert.AreEqual(tree.TotalProjects, totalProjects);
                }
                else
                {
                    Assert.AreNotEqual(tree.TotalProjects, totalProjects);
                }

                var localPagedResponse = _projects
                            .OrderBy(p => p.Site.Name)
                            .Where(p => !String.IsNullOrEmpty(p.Site.Name) && p.Site.Name.ToLower().IndexOf(searchText.ToLower()) != -1)
                            .Skip((pageNumber - 1) * pageSize)
                            .Take(pageSize)
                            .ToArray();

                //test count total items (counting recursively)
                Assert.AreEqual(localPagedResponse.Sum(l => l.CountNodes()), tree.CurrentPageItems.Length);

                Assert.AreEqual(localPagedResponse.Count(p => !p.Site.ParentSiteID.HasValue), tree.CurrentPageItems.Count(p => !p.ParentSiteID.HasValue));
                Assert.AreEqual(_projects.Count(p => !String.IsNullOrEmpty(p.Site.Name) && p.Site.Name.ToLower().IndexOf(searchText.ToLower()) != -1), tree.TotalProjects);

                var dropped = new List<Models.TreeNode>();
                for (int i = 0; i < tree.CurrentPageItems.Length; i++)
                {
                    if (localPagedResponse.Any(l => l.Found(tree.CurrentPageItems[i])))
                    {
                        dropped.Add(tree.CurrentPageItems[i]);
                        tree.CurrentPageItems[i] = null;
                    }
                }

                //make sure all items from db were cached by the local
                Assert.IsTrue(tree.CurrentPageItems.All(t => t == null));
            }

            #endregion

            #region site filter

            //test filtering to specific project
            for (int pIndex = 0; pIndex < totalProjects; pIndex++)
            {
                var t = _projects[pIndex];
                TestFilterSite_Recursivly(t);
            }

            #endregion
        }

        [TestMethod()]
        public void GetProjectPageNumber_Test()
        {
            int totalProjects = 5;
            var _projects = _CreateTree(totalProjects, 2)
                                .OrderBy(p => p.Site.Name)
                                .ToArray();

            int totalTreeNodes = _projects.Sum(c => c.CountNodes());
            Debug.WriteLine("GetProjectPageNumber_Test :: Total nodes in tested tree={0}, Total Projects={1}", totalTreeNodes, totalProjects);

            for (int pageSize = 1; pageSize <= totalProjects + 1; pageSize++)
            {
                for (int i = 0; i < totalProjects; i++)
                {
                    int expectedPageNumber = (i + 1) / pageSize + ((i + 1) % pageSize == 0 ? 0 : 1);
                    Assert.AreEqual(expectedPageNumber, rep.GetSitePageNumber(_projects[i].Site.SiteID, _user.UserID, pageSize));

                    //test all nodes in tree...
                    for (int cIndex = 0; cIndex < _projects[i].Children.Count; cIndex++)
                    {
                        foreach (var c in _projects[i].Select())
                        {
                            Assert.AreEqual(expectedPageNumber, rep.GetSitePageNumber(c.Item2.Site.SiteID, _user.UserID, pageSize));
                        }
                    }
                }
            }
        }

        [TestMethod()]
        public void ValidateOwnership_Site_Test()
        {
            var tree = _CreateTree(3);

            //another user
            var anotherUser = GeneralHelper.CreateTesterUser();
            var anotherUser_tree = _CreateTree(3, userID: anotherUser.UserID);

            foreach (var p in tree)
            {
                foreach (var c in p.Select(includeSelf: false))
                {
                    //should be null
                    var crossTreeLink = rep.ValidateOwnership_Site(anotherUser.UserID, c.Item2.Site.SiteID);
                    Assert.IsNull(crossTreeLink);

                    var userTreeLink = rep.ValidateOwnership_Site(_user.UserID, c.Item2.Site.SiteID);
                    Assert.IsNotNull(userTreeLink);
                    Assert.AreEqual(_user.UserID, userTreeLink.LinkedUserID);
                    Assert.AreEqual(c.Item2.Site.SiteID, userTreeLink.SiteID);
                    Assert.AreEqual(c.Item2.Site.Name, userTreeLink.SiteName);
                    Assert.AreEqual(c.Item2.Site.ParentSiteID, userTreeLink.ParentSiteID);
                    Assert.AreEqual(true, userTreeLink.IsVerified);
                    Assert.AreEqual(c.Item2.Site.ParentSiteID == null ? true : false, userTreeLink.IsDirectLink);
                }
            }
        }

        [TestMethod()]
        public void ValidateOwnership_Project_Test()
        {
            var tree = _CreateTree(3);

            //another user
            var anotherUser = GeneralHelper.CreateTesterUser();
            var anotherUser_tree = _CreateTree(3, userID: anotherUser.UserID);

            foreach (var p in tree)
            {
                //should be null
                var crossTreeLink = rep.ValidateOwnership_Project(p.Site.SiteID, anotherUser.UserID);
                Assert.IsNull(crossTreeLink);

                var userTreeLink = rep.ValidateOwnership_Project(_user.UserID, p.Site.SiteID);
                Assert.IsNotNull(userTreeLink);
                Assert.IsTrue(userTreeLink.IsDirectLink);

                Assert.AreEqual(_user.UserID, userTreeLink.LinkedUserID);
                Assert.AreEqual(p.Site.SiteID, userTreeLink.SiteID);
                Assert.AreEqual(p.Site.Name, userTreeLink.SiteName);
                Assert.AreEqual(p.Site.ParentSiteID, userTreeLink.ParentSiteID);
                Assert.AreEqual(true, userTreeLink.IsVerified);
                Assert.AreEqual(p.Site.ParentSiteID == null ? true : false, userTreeLink.IsDirectLink);
            }
        }

        [TestMethod()]
        public void AddProject_Test()
        {
            for (int i = 0; i < 2; i++)
            {
                var p = _CreateSiteObj(i);
            }
        }

        [TestMethod()]
        public void GetProject_Test()
        {
            //covered by AddProject_Test
            Assert.IsTrue(true);
        }

        [TestMethod()]
        public void GetProjects_Test()
        {
            int totalProjects = 10;
            var projects = new Models.MainSite[totalProjects];
            for (int i = 0; i < totalProjects; i++)
            {
                projects[i] = _CreateSiteObj(i, null);
            }

            #region regular (No Search, no paging)

            //test get
            var sameProjects = rep.GetProjects(_user.UserID);

            Assert.AreEqual(sameProjects.CurrentPageItems.Length, projects.Length);
            Assert.AreEqual(sameProjects.CurrentPageItems.Length, sameProjects.TotalItems);
            var items = sameProjects.CurrentPageItems
                .OrderBy(p => p.SiteID)
                .ToArray();

            for (int i = 0; i < totalProjects; i++)
            {
                Assert.AreEqual(projects[i].SiteID, items[i].SiteID);
                Assert.AreEqual(projects[i].Name, items[i].Name);
            }

            #endregion
        }

        [TestMethod()]
        public void UpdateProject_Test()
        {
            var p = _CreateSiteObj(2);
            var newName = $"NewName-{rand.Next(1000, 100000)}";
            Assert.AreNotEqual(p.Name, newName);

            Assert.IsTrue(rep.UpdateProject(p.SiteID, newName));

            var sameProject = rep.GetProject(p.SiteID);
            Assert.AreEqual(newName, sameProject.Name);
        }

        [TestMethod()]
        public void DeleteProject_Test()
        {
            var project = _CreateSiteObj(3);
            var site1 = _CreateSiteObj(4, project.SiteID);
            var site2 = _CreateSiteObj(5, project.SiteID);

            Assert.IsTrue(rep.DeleteProject(project.SiteID, _user.UserID));

            //validate project deletion
            Assert.IsNull(rep.GetProject(project.SiteID));

            //validate site deletion
            Assert.IsNull(rep.GetSite(site1.SiteID));
            Assert.IsNull(rep.GetSite(site2.SiteID));

            //manually remove from list since we don't need this cleanup.
            _CreatedProjects.RemoveAll(p => p.Item2 == project);
            _CreatedSites.RemoveAll(s => s.Item2 == site1);
            _CreatedSites.RemoveAll(s => s.Item2 == site2);
        }

        [TestMethod()]
        public void GetSiteLocation_Test()
        {
            var project = _CreateSiteObj(0);

            var location = rep.GetSiteLocation(project.SiteID);
            Assert.IsNotNull(location);
            Assert.AreEqual(location.MapCenter_AutoBounds, project.MapCenter_AutoBounds);
            Assert.AreEqual(location.MapCenter_Latitude, project.MapCenter_Latitude);
            Assert.AreEqual(location.MapCenter_Longitude, project.MapCenter_Longitude);
            Assert.AreEqual(location.MapCenter_Mode, project.MapCenter_Mode);
            Assert.AreEqual(location.MapCenter_Zoom, project.MapCenter_Zoom);

            //change location
            var newLocation = new Models.MapLocationData()
            {
                MapCenter_AutoBounds = !location.MapCenter_AutoBounds,
                MapCenter_Latitude = $"{rand.Next(1000, 2000)}",
                MapCenter_Longitude = $"{rand.Next(1000, 2000)}",
                MapCenter_Mode = $"{rand.Next(0, 10)}",
                MapCenter_Zoom = (byte)rand.Next(0, 255)
            };
            Assert.IsTrue(rep.UpdateSiteLocation(project.SiteID, newLocation));

            //validate the change
            var exists_newLocation = rep.GetSiteLocation(project.SiteID);
            Assert.IsNotNull(exists_newLocation);
            Assert.AreEqual(exists_newLocation.MapCenter_AutoBounds, newLocation.MapCenter_AutoBounds);
            Assert.AreEqual(exists_newLocation.MapCenter_Latitude, newLocation.MapCenter_Latitude);
            Assert.AreEqual(exists_newLocation.MapCenter_Longitude, newLocation.MapCenter_Longitude);
            Assert.AreEqual(exists_newLocation.MapCenter_Mode, newLocation.MapCenter_Mode);
            Assert.AreEqual(exists_newLocation.MapCenter_Zoom, newLocation.MapCenter_Zoom);
        }

        [TestMethod()]
        public void UpdateSiteLocation_Test()
        {
            //covered by GetSiteLocation_Test
            Assert.IsTrue(true);
        }

        [TestMethod()]
        public void GetSiteInfo_Test()
        {
            var tree = _CreateTree(3, 3);

            int totalTreeNodes = tree.Sum(c => c.CountNodes());
            Debug.WriteLine("GetSiteInfo_Test :: Total nodes in tested tree={0}", totalTreeNodes);

            foreach (var project in tree)
            {
                //verify project info
                var projectInfo = rep.GetSiteInfo(_user.UserID, project.Site.SiteID);
                Assert.IsNotNull(projectInfo);
                Assert.AreEqual(_user.UserID, projectInfo.LinkedUserID);

                Assert.AreEqual(project.Site.SiteID, projectInfo.SiteID);
                Assert.AreEqual(project.Site.ParentSiteID, projectInfo.ParentSiteID);
                Assert.AreEqual(project.Site.Name, projectInfo.SiteName);
                Assert.AreEqual(project.Site.Name, projectInfo.RootSiteName);
                Assert.AreEqual(project.Site.SiteID, projectInfo.RootSiteID);

                //test total children for this project
                Assert.AreEqual(project.Children.Count, projectInfo.TotalSitesDirect);

                //verify project info bits
                Assert.IsTrue(projectInfo.IsDirectLink);
                Assert.IsTrue(projectInfo.IsVerified.GetValueOrDefault(false));
                Assert.AreEqual(1, projectInfo.Level);
                Assert.IsFalse(projectInfo.IsShareBranch);

                foreach (var c in project.Select(1, includeSelf: false))
                {
                    var siteInfo = rep.GetSiteInfo(_user.UserID, c.Item2.Site.SiteID);
                    Assert.AreEqual(_user.UserID, siteInfo.LinkedUserID);

                    Assert.IsNotNull(siteInfo);
                    Assert.AreEqual(c.Item2.Site.SiteID, siteInfo.SiteID);
                    Assert.AreEqual(c.Item2.Site.ParentSiteID, siteInfo.ParentSiteID);
                    Assert.AreEqual(c.Item2.Site.Name, siteInfo.SiteName);

                    //project / root Site
                    Assert.AreEqual(project.Site.Name, siteInfo.RootSiteName);
                    Assert.AreEqual(project.Site.SiteID, siteInfo.RootSiteID);
                    Assert.AreEqual(c.Item2.Children.Count, siteInfo.TotalSitesDirect);

                    //this site LinkId should be the same as the project
                    Assert.AreEqual(projectInfo.LinkID, siteInfo.LinkID);

                    //verify project info bits
                    Assert.IsFalse(siteInfo.IsDirectLink);
                    Assert.IsTrue(siteInfo.IsVerified.GetValueOrDefault(false));
                    Assert.AreEqual(c.Item1, siteInfo.Level);
                    Assert.IsFalse(siteInfo.IsShareBranch);

                    //bits
                    Assert.IsTrue(siteInfo.RoleAdmin);
                    Assert.IsTrue(siteInfo.RoleControlRT);
                    Assert.IsTrue(siteInfo.RoleModify);
                    Assert.IsTrue(siteInfo.RoleViewOnly);
                }
            }
        }

        [TestMethod()]
        public void DevicesAlerts_GetAll_Test()
        {
            //create tree
            var project = _CreateTree(1, 4, 3)[0];
            int devicesPerNode = 3;

            //iteration twice for 2 options for alerts bits.
            for (int i = 0; i < 2; i++)
            {
                bool even_isEnabled_DeviceAlerts = i % 2 != 0;
                bool even_isEnabled_User2Device = i % 2 == 0;

                #region validate alerts functions on ALL nodes in this project tree

                foreach (var c in project.Select(1, true))
                {
                    //get all devices in this node (entire sub tree)
                    var nodeDevices = rep.GetUserTreeDevices(c.Item2.Site.SiteID, _user.UserID);
                    Assert.IsNotNull(nodeDevices);

                    //set devices to be in expected values (User2Device and MainDevice.IsAlertsEnabled)
                    for (int deviceIndex = 0; deviceIndex < nodeDevices.Length; deviceIndex++)
                    {
                        Assert.IsTrue(deviceRep.rep.UpdateAlertsEnabled(
                                                    nodeDevices[deviceIndex].SN,
                                                    nodeDevices[deviceIndex].DeviceID % 2 == 0 ? even_isEnabled_DeviceAlerts : !even_isEnabled_DeviceAlerts));

                        //only even index will get the isEnabled bits
                        Assert.IsTrue(rep.DevicesAlerts_UpdateUser(
                                                                nodeDevices[deviceIndex].DeviceID % 2 == 0 ? even_isEnabled_User2Device : !even_isEnabled_User2Device,
                                                                nodeDevices[deviceIndex].DeviceID,
                                                                _user.UserID));
                    }


                    int totalNodeDevices = c.Item2.CountNodes() * devicesPerNode;

                    #region  testing part
                    for (int pageSize = 1; pageSize <= totalNodeDevices + 1; pageSize++)
                    {
                        int totalPages = (totalNodeDevices / pageSize) + (totalNodeDevices % pageSize == 0 ? 0 : 1);

                        for (int pageNumber = 1; pageNumber <= totalPages + 1; pageNumber++)
                        {
                            #region get all, includes sub sites

                            var deviceAlerts_2subSite = rep.DevicesAlerts_GetAll(c.Item2.Site.SiteID, _user.UserID, true, pageNumber, pageSize);
                            Assert.IsNotNull(deviceAlerts_2subSite);
                            Assert.AreEqual(deviceAlerts_2subSite.TotalItems, totalNodeDevices);
                            Assert.AreEqual(deviceAlerts_2subSite.CurrentPageItems.Length, Math.Min(totalNodeDevices, pageNumber * pageSize) - Math.Min(totalNodeDevices, (pageNumber - 1) * pageSize));

                            //validate items
                            foreach (var item in deviceAlerts_2subSite.CurrentPageItems)
                            {
                                Assert.AreEqual(item.IsAlertsEnabled, item.DeviceID % 2 == 0 ? even_isEnabled_User2Device : !even_isEnabled_User2Device);
                                Assert.AreEqual(item.IsDeviceAlertsEnabled, item.DeviceID % 2 == 0 ? even_isEnabled_DeviceAlerts : !even_isEnabled_DeviceAlerts);
                            }

                            #endregion

                            #region get only direct devices

                            var deviceAlerts_2Site = rep.DevicesAlerts_GetAll(c.Item2.Site.SiteID, _user.UserID, false, pageNumber, pageSize);
                            Assert.IsNotNull(deviceAlerts_2Site);
                            Assert.AreEqual(deviceAlerts_2Site.TotalItems, devicesPerNode);
                            Assert.AreEqual(deviceAlerts_2Site.CurrentPageItems.Length, Math.Min(devicesPerNode, pageNumber * pageSize) - Math.Min(devicesPerNode, (pageNumber - 1) * pageSize));

                            //validate items
                            foreach (var item in deviceAlerts_2Site.CurrentPageItems)
                            {
                                Assert.AreEqual(item.SiteID, c.Item2.Site.SiteID);
                                Assert.AreEqual(item.IsAlertsEnabled, item.DeviceID % 2 == 0 ? even_isEnabled_User2Device : !even_isEnabled_User2Device);
                                Assert.AreEqual(item.IsDeviceAlertsEnabled, item.DeviceID % 2 == 0 ? even_isEnabled_DeviceAlerts : !even_isEnabled_DeviceAlerts);
                            }

                            #endregion
                        }
                    }

                    #endregion
                }

                #endregion
            }

        }

        [TestMethod()]
        public void GetSiteDirectDevices_Test()
        {
            int devicesPerNode = 3;
            var project = _CreateTree(2, 3, devicesPerNode)[0];

            foreach (var n in project.Select(1, true))
            {
                var devices = rep.GetSiteDirectDevices(project.Site.SiteID);
                Assert.IsNotNull(devices);
                Assert.IsTrue(devices.All(d => d != null));
                Assert.AreEqual(devices.Length, devicesPerNode);
            }
        }

        [TestMethod()]
        public void GetUserTreeDevices_Test()
        {
            int devicesPerNode = 3;
            var project = _CreateTree(2, 3, devicesPerNode)[0];

            foreach (var n in project.Select(1, true))
            {
                var devices = rep.GetUserTreeDevices(n.Item2.Site.SiteID, _user.UserID);
                
                Assert.IsNotNull(devices);
                Assert.IsTrue(devices.All(d => d != null));
                Assert.AreEqual(devices.Length, devicesPerNode * n.Item2.CountNodes());

                foreach (var d in devices)
                {
                    var localDevice = deviceRep._CreatedDevices.FirstOrDefault(d1 => d1.DeviceID == d.DeviceID);
                    Assert.IsNotNull(localDevice);

                    Assert.AreEqual(localDevice.Name, d.DeviceName);
                    Assert.AreEqual(localDevice.SN, d.SN);
                    Assert.AreEqual(localDevice.DeviceID, d.DeviceID);
                    Assert.AreEqual(localDevice.DeviceTypeID, d.DeviceTypeID);
                    Assert.AreEqual(localDevice.DeviceTypeName, d.DeviceTypeName);
                    Assert.AreEqual(localDevice.CreationDate, d.CreationDate);
                    Assert.AreEqual(localDevice.FirmwareVersion, d.FirmwareVersion);
                    Assert.AreEqual(localDevice.HoldUntilDate, d.HoldUntilDate);
                    Assert.AreEqual(localDevice.IsAlertsEnabled, d.IsAlertsEnabled);
                    Assert.AreEqual(localDevice.LastModifiedDate, d.LastModifiedDate);
                    Assert.AreEqual(localDevice.Map_Latitude, d.Map_Latitude);
                    Assert.AreEqual(localDevice.Map_Longitude, d.Map_Longitude);
                    Assert.AreEqual(localDevice.ParentSiteID, d.ParentSiteID);
                }
            }
        }

        [TestMethod()]
        public void DevicesAlerts_UpdateMacro_Test()
        {
            int devicesPerNode = 2;

            var project = _CreateTree(1, 3, devicesPerNode)[0];

            var states = new bool[] { true, false, true };
            for (int j = 0; j < 2; j++)
            {
                bool IncludeSub = j % 2 == 0;
                for (int i = 0; i < states.Length; i++)
                {
                    Assert.IsTrue(rep.DevicesAlerts_UpdateMacro(_user.UserID, project.Site.SiteID, states[i], IncludeSub));

                    var devices = rep.DevicesAlerts_GetAll(project.Site.SiteID, _user.UserID, IncludeSub, 1, 1000);
                    Assert.IsNotNull(devices);

                    foreach (var item in devices.CurrentPageItems)
                    {
                        Assert.AreEqual(item.IsAlertsEnabled, states[i]);
                    }
                }
            }
        }

        [TestMethod()]
        public void DevicesAlerts_UpdateUser_Test()
        {
            var project = _CreateSiteObj(0);

            var device = deviceRep._GetDevice(0, project.SiteID, true);
            Assert.IsNotNull(device);

            for (int i = 0; i < 2; i++)
            {
                //set value
                bool even_isEnabled_User2Device = i % 2 == 0;
                Assert.IsTrue(rep.DevicesAlerts_UpdateUser(
                                        even_isEnabled_User2Device,
                                        device.DeviceID,
                                        _user.UserID));


                //test
                var deviceAlerts_2Site = rep.DevicesAlerts_GetAll(project.SiteID, _user.UserID, false, 1, 1000);
                Assert.IsNotNull(deviceAlerts_2Site);
                Assert.AreEqual(deviceAlerts_2Site.TotalItems, 1);

                foreach (var item in deviceAlerts_2Site.CurrentPageItems)
                {
                    Assert.AreEqual(item.SiteID, project.SiteID);
                    Assert.AreEqual(item.IsAlertsEnabled, even_isEnabled_User2Device);
                }
            }

        }

        [TestMethod()]
        public void SaveDeviceLocation_Test()
        {
            var device = deviceRep._GetDevice(rand.Next(100, 200), null);
            var states = new bool[] { false, true, false };
            for (int i = 0; i < states.Length; i++)
            {
                var _Latitude = states[i] ? null : $"{rand.Next(1000, 9999) / 10m}";
                var _Longitude = states[i] ? null : $"{rand.Next(1000, 9999) / 10m}";

                Assert.IsTrue(rep.SaveDeviceLocation(device.SN, _Latitude, _Longitude));

                //validate
                var existsDevice = deviceRep.rep.GetDevice(device.DeviceID);
                Assert.IsNotNull(existsDevice);

                Assert.AreEqual(existsDevice.Map_Longitude, _Longitude);
                Assert.AreEqual(existsDevice.Map_Latitude, _Latitude);
            }
        }

        /// <summary>
        /// Covers the most common scenarios.
        /// More advanced scenarios will be covered by ShareSite_Accept_Test
        /// </summary>
        [TestMethod()]
        public void SharedUsers_Add_Test()
        {
            //build a tree to play with
            int devicesPerNode = 5;
            var projects = _CreateTree(3, 3, devicesPerNode);

            long SiteID = projects[0].Site.SiteID;
            var localCreatedUsers = new List<long>();

            //hold the tree for source userID
            var ownerDevices = rep.GetUserTreeDevices(SiteID, _user.UserID);
            Assert.AreEqual(ownerDevices.Length, devicesPerNode * projects[0].CountNodes());

            //validate list (since it's project, it should contain current user)
            var users = rep.SharedUsers_GetAll(SiteID);
            Assert.IsNotNull(users);
            Assert.AreEqual(1, users.Length);

            var states = new bool[] { false, true, false };
            long totalDevicesForTargetUsers = 0;

            for (int i = 0; i < states.Length; i++)
            {
                //create the user and its tree
                var anotherUser = GeneralHelper.CreateTesterUser();
                localCreatedUsers.Add(anotherUser.UserID);

                int anotherUser_devicesPerSite = 3;
                var anotherUser_tree = _CreateTree(1, 3, anotherUser_devicesPerSite, anotherUser.UserID);
                totalDevicesForTargetUsers = anotherUser_devicesPerSite * anotherUser_tree.Sum(c => c.CountNodes());

                var u2s = new Models.User2Site()
                {
                    LinkedUserID = anotherUser.UserID,
                    SiteID = SiteID,
                    RoleAdmin = i % 2 == 0 ? !states[i] : !states[i],
                    RoleControlRT = i % 2 == 0 ? states[i] : !states[i],
                    RoleModify = i % 2 == 0 ? !states[i] : !states[i],
                    RoleViewOnly = i % 2 == 0 ? states[i] : !states[i],
                };

                #region ------------------------------ADD------------------------------------------
                bool? IsComplete = null;
                Assert.IsTrue(rep.SharedUsers_Add(_user.UserID, u2s, out IsComplete));
                Assert.IsTrue(IsComplete.HasValue && !IsComplete.Value);
                Assert.AreNotEqual(u2s.LinkID, -1);
                //trying again the same - should fail.
                Assert.IsFalse(rep.SharedUsers_Add(_user.UserID, u2s, out IsComplete));
                Assert.IsFalse(IsComplete.HasValue);
                Assert.IsNotNull(rep.Connector.LastException);

                //validate
                var existsUsers = rep.SharedUsers_GetAll(SiteID);
                Assert.IsNotNull(existsUsers);
                Assert.AreEqual(1 + localCreatedUsers.Count, existsUsers.Length);
                Assert.AreEqual(1, existsUsers.Count(u => u.LinkedUserID == anotherUser.UserID));

                //validate properties
                var existsUser = existsUsers.FirstOrDefault(u => u.LinkedUserID == anotherUser.UserID);
                Assert.AreEqual(existsUser.LinkedUserID, anotherUser.UserID);
                Assert.AreEqual(existsUser.Email, anotherUser.Email);
                Assert.AreEqual(existsUser.RoleAdmin, u2s.RoleAdmin);
                Assert.AreEqual(existsUser.RoleControlRT, u2s.RoleControlRT);
                Assert.AreEqual(existsUser.RoleModify, u2s.RoleModify);
                Assert.AreEqual(existsUser.RoleViewOnly, u2s.RoleViewOnly);
                Assert.AreEqual(existsUser.LastActionUserID, _user.UserID);
                Assert.IsNull(existsUser.IsVerified);
                Assert.AreNotEqual(-1, existsUser.LinkID);


                #endregion

                #region -----------------------------UPDATE----------------------------------------

                u2s.RoleAdmin = !u2s.RoleAdmin;
                u2s.RoleControlRT = !u2s.RoleControlRT;
                u2s.RoleModify = !u2s.RoleModify;
                u2s.RoleViewOnly = !u2s.RoleViewOnly;

                Assert.IsTrue(rep.SharedUsers_Update(_user.UserID, u2s));
                existsUsers = rep.SharedUsers_GetAll(SiteID);
                Assert.IsNotNull(existsUsers);
                Assert.AreEqual(1 + i + 1, existsUsers.Length);
                Assert.AreEqual(1, existsUsers.Count(u => u.LinkedUserID == anotherUser.UserID));

                //validate properties
                existsUser = existsUsers.FirstOrDefault(u => u.LinkedUserID == anotherUser.UserID);
                Assert.AreEqual(existsUser.LinkedUserID, anotherUser.UserID);
                Assert.AreEqual(existsUser.Email, anotherUser.Email);
                Assert.AreEqual(existsUser.RoleAdmin, u2s.RoleAdmin);
                Assert.AreEqual(existsUser.RoleControlRT, u2s.RoleControlRT);
                Assert.AreEqual(existsUser.RoleModify, u2s.RoleModify);
                Assert.AreEqual(existsUser.RoleViewOnly, u2s.RoleViewOnly);
                Assert.AreEqual(existsUser.LastActionUserID, _user.UserID);
                Assert.IsNull(existsUser.IsVerified);
                Assert.AreNotEqual(-1, existsUser.LinkID);

                #endregion

                //make sure target user still don't have access to owner devices
                var tagretDevices = rep.GetUserTreeDevices(SiteID, anotherUser.UserID);
                Assert.AreEqual(0, tagretDevices.Length);

                if (i % 2 == 0)
                {
                    //even index - REJECT
                    #region -----------------------------REJECT----------------------------------------

                    Assert.IsTrue(rep.SharedUsers_Reject(SiteID, _user.UserID, anotherUser.UserID));
                    existsUsers = rep.SharedUsers_GetAll(SiteID);
                    Assert.AreEqual(1, existsUsers.Count(u => u.LinkedUserID == anotherUser.UserID));
                    existsUser = existsUsers.FirstOrDefault(u => u.LinkedUserID == anotherUser.UserID);
                    Assert.AreEqual(existsUser.LinkedUserID, anotherUser.UserID);
                    Assert.AreEqual(existsUser.RoleAdmin, u2s.RoleAdmin);
                    Assert.AreEqual(existsUser.RoleControlRT, u2s.RoleControlRT);
                    Assert.AreEqual(existsUser.RoleModify, u2s.RoleModify);
                    Assert.AreEqual(existsUser.RoleViewOnly, u2s.RoleViewOnly);
                    //as rejected - expected to be false
                    Assert.IsTrue(existsUser.IsVerified.HasValue && !existsUser.IsVerified.Value);

                    #endregion
                }
                else
                {
                    #region -----------------------------ACCEPT----------------------------------------

                    //test before accept
                    var anotherUser_AllDevices = rep.GetDevicesSubscribed(anotherUser.UserID);
                    Assert.AreEqual(totalDevicesForTargetUsers, anotherUser_AllDevices.Length);
                    var anotherUser_siteDevices = rep.GetUserTreeDevices(anotherUser_tree[0].Site.SiteID, anotherUser.UserID);
                    Assert.AreEqual(anotherUser_tree[0].CountNodes() * anotherUser_devicesPerSite, anotherUser_siteDevices.Length);

                    //accept to first project
                    Assert.IsTrue(rep.ShareSite_Accept(SiteID, anotherUser.UserID, anotherUser_tree[0].Site.SiteID));

                    //test Device2User
                    anotherUser_AllDevices = rep.GetDevicesSubscribed(anotherUser.UserID);
                    Assert.AreEqual(ownerDevices.Length + (anotherUser_tree[0].CountNodes() * anotherUser_devicesPerSite), anotherUser_AllDevices.Length);
                    foreach (var d in ownerDevices)
                    {
                        Assert.AreEqual(1, anotherUser_AllDevices.Count(a => a.DeviceID == d.DeviceID));
                    }

                    //make sure target user got devices with the right permissions
                    anotherUser_siteDevices = rep.GetUserTreeDevices(anotherUser_tree[0].Site.SiteID, anotherUser.UserID);
                    Assert.AreEqual(anotherUser_siteDevices.Length, anotherUser_AllDevices.Length);
                    foreach (var d in ownerDevices)
                    {
                        Assert.AreEqual(1, anotherUser_siteDevices.Count(a => a.DeviceID == d.DeviceID));
                    }

                    //validate users in User2Site
                    var users_afterAccept = rep.SharedUsers_GetAll(SiteID);
                    Assert.AreEqual(1, users_afterAccept.Count(c => c.LinkedUserID == anotherUser.UserID && c.IsVerified == true));

                    #endregion
                }
            }

            #region -----------------------------DELETE----------------------------------------
            for (int i = 0; i < localCreatedUsers.Count; i++)
            {
                //calculate expected count
                //(add 1 for the Source user (_user.UserID))
                int expectedUsersCount = 1 + localCreatedUsers.Count - i;
                //before delete
                var existsUsers = rep.SharedUsers_GetAll(SiteID);
                Assert.AreEqual(existsUsers.Length, expectedUsersCount);

                //delete
                Assert.IsTrue(rep.SharedUsers_Delete(SiteID, _user.UserID, localCreatedUsers[i]));
                existsUsers = rep.SharedUsers_GetAll(SiteID);
                Assert.IsFalse(existsUsers.Any(u => u.LinkedUserID == localCreatedUsers[i]));
                Assert.AreEqual(existsUsers.Length, expectedUsersCount - 1);

                //make sure the user lost the devices
                //anotherUser_devicesPerSite
                var anotherUser_AllDevices = rep.GetDevicesSubscribed(localCreatedUsers[i]);
                Assert.AreEqual(totalDevicesForTargetUsers, anotherUser_AllDevices.Length);
            }
            #endregion

            //test at last we have only _user.UserID as connected
            var finalExistsUsers = rep.SharedUsers_GetAll(SiteID);
            Assert.AreEqual(finalExistsUsers.Length, 1);
            Assert.AreEqual(1, finalExistsUsers.Count(u => u.LinkedUserID == _user.UserID));
        }

        [TestMethod()]
        public void SharedUsers_Update_Test()
        {
            //covered by SharedUsers_Add_Test
            Assert.IsTrue(true);
        }

        [TestMethod()]
        public void SharedUsers_GetAll_Test()
        {
            //covered by SharedUsers_Add_Test
            Assert.IsTrue(true);
        }

        [TestMethod()]
        public void SharedUsers_Delete_Test()
        {
            //covered by SharedUsers_Add_Test
            Assert.IsTrue(true);
        }

        [TestMethod()]
        public void SharedUsers_Reject_Test()
        {
            //covered by SharedUsers_Add_Test
            Assert.IsTrue(true);
        }

        [TestMethod()]
        public void ShareSite_Accept_Test()
        {
            //share a site "mainSite_2Share" and then share another site that under it (site subSite_2Share)
            //unshare site "mainSite_2Share", unshare the subset site (subSite_2Share)

            //--------------------------------PREPARE--------------------------------
            //settings
            //create source user
            var sourceUser = GeneralHelper.CreateTesterUser();
            int sourceUser_devicesPerNode = 5;
            var sourceUser_tree = _CreateTree(4, 3, sourceUser_devicesPerNode, sourceUser.UserID);

            //create target user
            var targetUser = GeneralHelper.CreateTesterUser();
            int targetUser_devicesPerNode = 3;
            var targetUser_tree = _CreateTree(4, 3, targetUser_devicesPerNode, targetUser.UserID);

            //sites to share
            var source_mainSite_2Share = sourceUser_tree[0].Select(includeSelf: false).FirstOrDefault(c => c.Item2.Children.Count > 0).Item2;
            var source_subSite_2Share = source_mainSite_2Share.Children[0];

            //target location for share (int target user's tree)
            var target_targetSite4Share = targetUser_tree[0].Children.FirstOrDefault(c => c.Children.Count > 0);
            var target_anotherProject_4share = targetUser_tree[1];

            Debug.WriteLine("-----------------------------ShareSite_Accept_Test-----------------------------");
            Debug.WriteLine("Source User:{0}", sourceUser.UserID);
            Debug.WriteLine("source_mainSite_2Share:{0}  -->> {1}", source_mainSite_2Share.Site.SiteID, source_subSite_2Share.Site.SiteID);
            Debug.WriteLine("Target User:{0}", targetUser.UserID);
            Debug.WriteLine("target_targetSite4Share:{0}", target_targetSite4Share.Site.SiteID);
            //-----------------------------TEST (BEFORE)-----------------------------
            //source - test before
            var devices_sourceUser_project0 = rep.GetUserTreeDevices(source_mainSite_2Share.Site.SiteID, sourceUser.UserID);
            Assert.AreEqual(source_mainSite_2Share.CountNodes() * sourceUser_devicesPerNode, devices_sourceUser_project0.Length);
            //target - test before
            var devices_targetUser_project0 = rep.GetUserTreeDevices(target_targetSite4Share.Site.SiteID, targetUser.UserID);
            Assert.AreEqual(target_targetSite4Share.CountNodes() * targetUser_devicesPerNode, devices_targetUser_project0.Length);

            foreach (var sourceD in devices_sourceUser_project0)
            {
                Assert.IsFalse(devices_targetUser_project0.Any(d => d.DeviceID == sourceD.DeviceID));
            }

            //test target user on the source site (should fail)
            var devices_targetUser_project0_2 = rep.GetUserTreeDevices(source_mainSite_2Share.Site.SiteID, targetUser.UserID);
            Assert.AreEqual(0, devices_targetUser_project0_2.Length);

            //--------------------------------SHARE (1)-------------------------------
            //ADD share site
            bool? IsComplete = null;
            var u2s_mainSite = new User2Site()
            {
                SiteID = source_mainSite_2Share.Site.SiteID,
                Email = targetUser.Email,
                RoleAdmin = true,
                RoleControlRT = true,
                RoleModify = true,
                RoleViewOnly = true
            };
            Assert.IsTrue(rep.SharedUsers_Add(sourceUser.UserID, u2s_mainSite, out IsComplete));

            Assert.IsTrue(IsComplete.HasValue && !IsComplete.Value);
            //ACCEPT share under target_targetSite4Share
            Assert.IsTrue(rep.ShareSite_Accept(source_mainSite_2Share.Site.SiteID, targetUser.UserID, target_targetSite4Share.Site.SiteID));

            //-----------------------------TEST (AFTER)-----------------------------
            var targetUser_updatedTree = rep.GetTree(targetUser.UserID, 1, 10000);
            var sharedSite = targetUser_updatedTree.CurrentPageItems.FirstOrDefault(s => s.SiteID == source_mainSite_2Share.Site.SiteID);
            Assert.IsNotNull(sharedSite);
            Assert.AreEqual(u2s_mainSite.RoleAdmin, sharedSite.RoleAdmin);
            Assert.AreEqual(u2s_mainSite.RoleControlRT, sharedSite.RoleControlRT);
            Assert.AreEqual(u2s_mainSite.RoleModify, sharedSite.RoleModify);
            Assert.AreEqual(u2s_mainSite.RoleViewOnly, sharedSite.RoleViewOnly);

            var shared_subSite = targetUser_updatedTree.CurrentPageItems.FirstOrDefault(s => s.SiteID == source_subSite_2Share.Site.SiteID);
            Assert.IsNotNull(shared_subSite);
            Assert.AreEqual(u2s_mainSite.RoleAdmin, shared_subSite.RoleAdmin);
            Assert.AreEqual(u2s_mainSite.RoleControlRT, shared_subSite.RoleControlRT);
            Assert.AreEqual(u2s_mainSite.RoleModify, shared_subSite.RoleModify);
            Assert.AreEqual(u2s_mainSite.RoleViewOnly, shared_subSite.RoleViewOnly);

            //test source devices are accessible by the target
            devices_targetUser_project0_2 = rep.GetUserTreeDevices(source_mainSite_2Share.Site.SiteID, targetUser.UserID);
            Assert.AreEqual(source_mainSite_2Share.CountNodes() * sourceUser_devicesPerNode, devices_targetUser_project0_2.Length);
            //test source devices are accessible by the target - from target site (where the share located)
            devices_targetUser_project0 = rep.GetUserTreeDevices(target_targetSite4Share.Site.SiteID, targetUser.UserID);
            Assert.AreEqual((target_targetSite4Share.CountNodes() * targetUser_devicesPerNode) + (source_mainSite_2Share.CountNodes() * sourceUser_devicesPerNode), devices_targetUser_project0.Length);

            var mainSite_users = rep.SharedUsers_GetAll(source_mainSite_2Share.Site.SiteID);
            var mainsite_LinkID = mainSite_users.FirstOrDefault(c => c.LinkedUserID == targetUser.UserID && c.IsVerified == true);
            Assert.IsNotNull(mainsite_LinkID);
            Assert.AreEqual(1, mainSite_users.Count(c => c.LinkedUserID == targetUser.UserID && c.IsVerified == true));

            //--------------------------------SHARE (2)-------------------------------
            //ADD share to another site that already in the shared site's  tree (source_site2Share.Site.SiteID)
            //ADD share site
            IsComplete = null;
            var u2s_subSite = new User2Site()
            {
                SiteID = source_subSite_2Share.Site.SiteID,
                Email = targetUser.Email,
                RoleAdmin = false,
                RoleControlRT = true,
                RoleModify = true,
                RoleViewOnly = true
            };
            Assert.IsTrue(rep.SharedUsers_Add(sourceUser.UserID, u2s_subSite, out IsComplete));

            Assert.IsTrue(IsComplete.HasValue && IsComplete.Value);
            //ACCEPT share under target_targetSite4Share
            //SHOULD FAIL!!! - SINCE THE PROCCESS HAS BEEN ALREADY COMPLETED BY THE CALL TO "rep.SharedUsers_Add"
            Assert.IsFalse(rep.ShareSite_Accept(source_subSite_2Share.Site.SiteID, targetUser.UserID, target_anotherProject_4share.Site.SiteID));

            //check users in both sites
            mainSite_users = rep.SharedUsers_GetAll(source_mainSite_2Share.Site.SiteID);
            Assert.AreEqual(1, mainSite_users.Count(c => c.LinkID == mainsite_LinkID.LinkID && c.LinkedUserID == targetUser.UserID && c.IsVerified == true));
            var subSite_users = rep.SharedUsers_GetAll(source_subSite_2Share.Site.SiteID);
            Assert.AreEqual(1, subSite_users.Count(c => c.LinkID != mainsite_LinkID.LinkID && c.LinkedUserID == targetUser.UserID && c.IsVerified == true));

            //test the target user
            targetUser_updatedTree = rep.GetTree(targetUser.UserID, 1, 10000);
            sharedSite = targetUser_updatedTree.CurrentPageItems.FirstOrDefault(s => s.SiteID == source_mainSite_2Share.Site.SiteID);
            Assert.IsNotNull(sharedSite);
            Assert.AreEqual(u2s_mainSite.RoleAdmin, sharedSite.RoleAdmin);
            Assert.AreEqual(u2s_mainSite.RoleControlRT, sharedSite.RoleControlRT);
            Assert.AreEqual(u2s_mainSite.RoleModify, sharedSite.RoleModify);
            Assert.AreEqual(u2s_mainSite.RoleViewOnly, sharedSite.RoleViewOnly);

            shared_subSite = targetUser_updatedTree.CurrentPageItems.FirstOrDefault(s => s.SiteID == source_subSite_2Share.Site.SiteID);
            Assert.AreEqual(1, targetUser_updatedTree.CurrentPageItems.Count(c => c.SiteID == source_subSite_2Share.Site.SiteID));

            Assert.IsNotNull(shared_subSite);
            Assert.AreEqual(u2s_subSite.RoleAdmin, shared_subSite.RoleAdmin);
            Assert.AreEqual(u2s_subSite.RoleControlRT, shared_subSite.RoleControlRT);
            Assert.AreEqual(u2s_subSite.RoleModify, shared_subSite.RoleModify);
            Assert.AreEqual(u2s_subSite.RoleViewOnly, shared_subSite.RoleViewOnly);


            //--------------------------------UN-SHARE (3)-------------------------------
            //unshare the main site link 
            //make sure the sub site will be relevant.
            Assert.IsTrue(rep.SharedUsers_Delete(source_mainSite_2Share.Site.SiteID, sourceUser.UserID, targetUser.UserID));

            //test link to sub site (should return)
            subSite_users = rep.SharedUsers_GetAll(source_subSite_2Share.Site.SiteID);
            Assert.AreEqual(1, subSite_users.Count(c => c.LinkID != mainsite_LinkID.LinkID && c.LinkedUserID == targetUser.UserID));

            //test link to main site (shouldn't return)
            mainSite_users = rep.SharedUsers_GetAll(source_mainSite_2Share.Site.SiteID);
            Assert.AreEqual(0, mainSite_users.Count(c => c.LinkID == mainsite_LinkID.LinkID || c.LinkedUserID == targetUser.UserID));

            //test tree
            targetUser_updatedTree = rep.GetTree(targetUser.UserID);
            Assert.AreEqual(0, targetUser_updatedTree.CurrentPageItems.Count(c => c.SiteID == source_mainSite_2Share.Site.SiteID));
            Assert.AreEqual(1, targetUser_updatedTree.CurrentPageItems.Count(c => c.SiteID == source_subSite_2Share.Site.SiteID));

        }

        [TestMethod()]
        public void GetDevicesSubscribed_Test()
        {
            //covered by SharedUsers_Add_Test
            Assert.IsTrue(true);
        }

        [TestMethod()]
        public void AddSite_Test()
        {
            var project = _CreateSiteObj(4);
            var site = _CreateSiteObj(5, project.SiteID);

            //get site
            var sameSite = rep.GetSite(site.SiteID);
            Assert.IsNotNull(sameSite);
        }

        [TestMethod()]
        public void GetSite_Test()
        {
            var site = _CreateSiteObj();
            var _site = rep.GetSite(site.SiteID);

            Assert.IsNotNull(_site);
            CompareSites(site, _site);
        }

        [TestMethod()]
        public void UpdateSite_Test()
        {
            var site = _CreateSiteObj(0);
            var oldName = site.Name;
            var newName = $"{site.Name}-{rand.Next(1, 1000)}";
            Assert.IsTrue(rep.UpdateSite(site.SiteID, newName));

            var existsSite = rep.GetSite(site.SiteID);
            Assert.AreNotEqual(existsSite.Name, site.Name);
            Assert.AreEqual(existsSite.Name, newName);
        }

        [TestMethod()]
        public void DeleteSite_Test()
        {
            //create project and site with another sub-site
            var project = _CreateSiteObj(0);

            var site = _CreateSiteObj(0, project.SiteID);
            var site_1 = _CreateSiteObj(0, site.SiteID);

            //validate they exists
            CompareSites(project, rep.GetSite(project.SiteID));
            CompareSites(site, rep.GetSite(site.SiteID));
            CompareSites(site_1, rep.GetSite(site_1.SiteID));

            //delete the site and make sure the sub-site was deleted as well
            Assert.IsTrue(rep.DeleteSite(site.SiteID, _user.UserID));
            Assert.IsNull(rep.GetSite(site.SiteID));
            Assert.IsNull(rep.GetSite(site_1.SiteID));

            //manually remove from lists
            _CreatedSites.RemoveAll(s => s.Item2 == site);
            _CreatedSites.RemoveAll(s => s.Item2 == site_1);

        }

        [TestMethod()]
        public void SiteTransfer_Start_Test()
        {
            //user 1 (SourceUser)
            var user1 = GeneralHelper.CreateTesterUser();
            var user1_tree = _CreateTree(3, 2, 2, user1.UserID);

            //user 2 (TargetUser)
            var user2 = GeneralHelper.CreateTesterUser();
            var user2_tree = _CreateTree(3, 2, 2, user2.UserID);

            //----------------------------------- START TRANSFER -----------------------------------
            var transferRequest = new NewTransferSiteRequest()
            {
                SiteID = user1_tree[0].Site.SiteID,
                SourceUserID = user1.UserID,
                TargetUserID = user2.UserID,
                MessageID = Guid.NewGuid().ToString()
            };
            Assert.IsTrue(rep.SiteTransfer_Start(transferRequest));

            var now = DateTime.UtcNow;
            var pendingRequests = rep.SiteTransfer_GetAllPendings(transferRequest.SiteID, transferRequest.SourceUserID);
            Assert.IsNotNull(pendingRequests);
            Assert.AreEqual(pendingRequests.Length, 1);

            foreach (var pendingRequest in pendingRequests)
            {
                Assert.AreEqual(pendingRequest.SiteID, transferRequest.SiteID);
                Assert.AreEqual(pendingRequest.SourceUserID, transferRequest.SourceUserID);
                Assert.AreEqual(pendingRequest.TargetUserEmail, user2.Email);
                Assert.AreEqual(pendingRequest.TargetUserID, transferRequest.TargetUserID);
                Assert.AreEqual(pendingRequest.MessageID, transferRequest.MessageID);

                Assert.IsTrue(Math.Abs((now - pendingRequest.TransferDate).TotalSeconds) < TimeSpan.FromSeconds(5).TotalSeconds);
                Assert.IsNull(pendingRequest.RejectDate);
            }
        }

        [TestMethod()]
        public void SiteTransfer_Cancel_Test()
        {
            //user 1 (SourceUser)
            var user1 = GeneralHelper.CreateTesterUser();
            var user1_tree = _CreateTree(3, 2, 2, user1.UserID);

            //user 2 (TargetUser)
            var user2 = GeneralHelper.CreateTesterUser();
            var user2_tree = _CreateTree(3, 2, 2, user2.UserID);

            //----------------------------------- START TRANSFER -----------------------------------
            var transferRequest = new NewTransferSiteRequest()
            {
                SiteID = user1_tree[0].Site.SiteID,
                SourceUserID = user1.UserID,
                TargetUserID = user2.UserID
            };
            Assert.IsTrue(rep.SiteTransfer_Start(transferRequest));

            var now = DateTime.UtcNow;
            var pendingRequests = rep.SiteTransfer_GetAllPendings(transferRequest.SiteID, transferRequest.SourceUserID);
            Assert.IsNotNull(pendingRequests);
            Assert.AreEqual(pendingRequests.Length, 1);

            foreach (var pendingRequest in pendingRequests)
            {
                Assert.AreEqual(pendingRequest.SiteID, transferRequest.SiteID);
                Assert.AreEqual(pendingRequest.SourceUserID, transferRequest.SourceUserID);
                Assert.AreEqual(pendingRequest.TargetUserEmail, user2.Email);
                Assert.AreEqual(pendingRequest.TargetUserID, transferRequest.TargetUserID);
                Assert.IsTrue(Math.Abs((now - pendingRequest.TransferDate).TotalSeconds) < TimeSpan.FromSeconds(5).TotalSeconds);
                Assert.IsNull(pendingRequest.RejectDate);
            }

            //----------------------------------- CANCEL TRANSFER -----------------------------------
            Assert.IsTrue(rep.SiteTransfer_Cancel(user1.UserID, transferRequest.SiteID));
            pendingRequests = rep.SiteTransfer_GetAllPendings(transferRequest.SiteID, transferRequest.SourceUserID);
            Assert.AreEqual(pendingRequests.Length, 0);
        }

        [TestMethod()]
        public void SiteTransfer_GetAllPendings_Test()
        {
            //covered by all Transfer tests
            Assert.IsTrue(true);
        }

        [TestMethod()]
        public void SiteTransfer_Reject_Test()
        {
            //user 1 (SourceUser)
            var user1 = GeneralHelper.CreateTesterUser();
            var user1_tree = _CreateTree(3, 2, 2, user1.UserID);

            //user 2 (TargetUser)
            var user2 = GeneralHelper.CreateTesterUser();
            var user2_tree = _CreateTree(3, 2, 2, user2.UserID);

            //----------------------------------- START TRANSFER -----------------------------------
            var transferRequest = new NewTransferSiteRequest()
            {
                SiteID = user1_tree[0].Site.SiteID,
                SourceUserID = user1.UserID,
                TargetUserID = user2.UserID
            };
            Assert.IsTrue(rep.SiteTransfer_Start(transferRequest));

            var now = DateTime.UtcNow;
            var pendingRequests = rep.SiteTransfer_GetAllPendings(transferRequest.SiteID, transferRequest.SourceUserID);
            Assert.IsNotNull(pendingRequests);
            Assert.AreEqual(pendingRequests.Length, 1);

            foreach (var request in pendingRequests)
            {
                Assert.AreEqual(request.SiteID, transferRequest.SiteID);
                Assert.AreEqual(request.SourceUserID, transferRequest.SourceUserID);
                Assert.AreEqual(request.TargetUserEmail, user2.Email);
                Assert.AreEqual(request.TargetUserID, transferRequest.TargetUserID);
                Assert.IsTrue(Math.Abs((now - request.TransferDate).TotalSeconds) < TimeSpan.FromSeconds(5).TotalSeconds);
                Assert.IsNull(request.RejectDate);
            }

            //----------------------------------- REJECT TRANSFER -----------------------------------
            var now_reject = DateTime.UtcNow;
            Assert.IsTrue(rep.SiteTransfer_Reject(user1.UserID, transferRequest.TargetUserID, transferRequest.SiteID));
            pendingRequests = rep.SiteTransfer_GetAllPendings(transferRequest.SiteID, transferRequest.SourceUserID);
            Assert.IsNotNull(pendingRequests);
            Assert.AreEqual(pendingRequests.Length, 1);

            foreach (var pendingRequest in pendingRequests)
            {
                Assert.AreEqual(pendingRequest.SiteID, transferRequest.SiteID);
                Assert.AreEqual(pendingRequest.SourceUserID, transferRequest.SourceUserID);
                Assert.AreEqual(pendingRequest.TargetUserEmail, user2.Email);
                Assert.AreEqual(pendingRequest.TargetUserID, transferRequest.TargetUserID);
                Assert.IsTrue(Math.Abs((now - pendingRequest.TransferDate).TotalSeconds) < TimeSpan.FromSeconds(5).TotalSeconds);
                Assert.IsNotNull(pendingRequest.RejectDate);
                Assert.IsTrue(Math.Abs((now_reject - pendingRequest.RejectDate.Value).TotalSeconds) < TimeSpan.FromSeconds(5).TotalSeconds);
            }
        }

        [TestMethod()]
        public void SiteTransfer_Accept_Test()
        {
            //user 1 (SourceUser)
            var user1 = GeneralHelper.CreateTesterUser();
            int user1_totalProjects = 3;
            int user1_devicesPerNode = 4;
            var user1_tree = _CreateTree(user1_totalProjects, 2, user1_devicesPerNode, user1.UserID);

            //user 2 (TargetUser)
            var user2 = GeneralHelper.CreateTesterUser();
            int user2_totalProjects = 4;
            int user2_devicesPerNode = 5;
            var user2_tree = _CreateTree(user2_totalProjects, 2, user2_devicesPerNode, user2.UserID);

            //----------------------------------- BEFORE TRANSFER -----------------------------------
            //prepare the transfer request 
            var transferRequest = new NewTransferSiteRequest()
            {
                SiteID = user1_tree[0].Site.SiteID,
                SourceUserID = user1.UserID,
                TargetUserID = user2.UserID
            };

            //save now the affected devices on this transfer for future compare
            var user1_devicesOnTransfer = rep.GetUserTreeDevices(transferRequest.SiteID, user1.UserID);
            Assert.AreEqual(user1_tree[0].CountNodes() * user1_devicesPerNode, user1_devicesOnTransfer.Length);

            //save the affected sites. if transfer succeed - we must ensure the Cleanup process will be done for them using the target user.
            var user1_sitesOnTransfer = user1_tree[0].Select().ToArray();

            //----------------------------------- START TRANSFER -----------------------------------

            Assert.IsTrue(rep.SiteTransfer_Start(transferRequest));

            var now = DateTime.UtcNow;
            var pendingRequests = rep.SiteTransfer_GetAllPendings(transferRequest.SiteID, transferRequest.SourceUserID);
            Assert.IsNotNull(pendingRequests);
            Assert.AreEqual(pendingRequests.Length, 1);

            foreach (var pendingRequest in pendingRequests)
            {
                Assert.AreEqual(pendingRequest.SiteID, transferRequest.SiteID);
                Assert.AreEqual(pendingRequest.SourceUserID, transferRequest.SourceUserID);
                Assert.AreEqual(pendingRequest.TargetUserEmail, user2.Email);
                Assert.AreEqual(pendingRequest.TargetUserID, transferRequest.TargetUserID);
                Assert.IsTrue(Math.Abs((now - pendingRequest.TransferDate).TotalSeconds) < TimeSpan.FromSeconds(5).TotalSeconds);
                Assert.IsNull(pendingRequest.RejectDate);
            }

            //----------------------------------- ACCEPRT TRANSFER -----------------------------------
            //accept as project
            Assert.IsTrue(rep.SiteTransfer_Accept(transferRequest.SiteID, user1.UserID, null, transferRequest.TargetUserID));
            pendingRequests = rep.SiteTransfer_GetAllPendings(transferRequest.SiteID, transferRequest.SourceUserID);
            Assert.AreEqual(pendingRequests.Length, 0);

            //validate transfer on user 1
            var user1_updatedTree = rep.GetTree(user1.UserID, 1, 1000);
            Assert.AreEqual(user1_totalProjects - 1, user1_updatedTree.CurrentPageItems.Count(s => !s.ParentSiteID.HasValue));
            Assert.AreEqual(0, user1_updatedTree.CurrentPageItems.Count(s => s.SiteID == transferRequest.SiteID));

            //validate transfer devices on user 1
            var user1_devicesOnTransfer_after = rep.GetUserTreeDevices(transferRequest.SiteID, user1.UserID);
            Assert.AreEqual(0, user1_devicesOnTransfer_after.Length);

            //validate transfer on user 2
            var user2_updatedTree = rep.GetTree(user2.UserID, 1, 1000);
            Assert.AreEqual(user2_totalProjects + 1, user2_updatedTree.CurrentPageItems.Count(s => !s.ParentSiteID.HasValue));
            Assert.AreEqual(1, user2_updatedTree.CurrentPageItems.Count(s => s.SiteID == transferRequest.SiteID));
            var newTransfferedProject = user2_updatedTree.CurrentPageItems.FirstOrDefault(s => s.SiteID == transferRequest.SiteID);

            //validate transfer devices on user 2
            var user2_devicesOnTransfer = rep.GetUserTreeDevices(transferRequest.SiteID, user2.UserID);
            Assert.AreEqual(user1_tree[0].CountNodes() * user1_devicesPerNode, user2_devicesOnTransfer.Length);

            //compare devices lists
            Assert.AreEqual(user1_devicesOnTransfer.Length, user2_devicesOnTransfer.Length);
            foreach (var d in user1_devicesOnTransfer)
            {
                Assert.IsTrue(user2_devicesOnTransfer.Any(dd => dd.DeviceID == d.DeviceID));
            }

            //test User2Device table - user 1
            var user1_allDevices = rep.GetDevicesSubscribed(user1.UserID);
            foreach (var d in user1_allDevices)
            {
                Assert.IsFalse(user1_devicesOnTransfer.Any(dd => dd.DeviceID == d.DeviceID));
            }

            //test User2Device table - user 2
            var user2_allDevices = rep.GetDevicesSubscribed(user2.UserID);
            foreach (var d in user1_devicesOnTransfer)
            {
                Assert.IsTrue(user1_devicesOnTransfer.Any(dd => dd.DeviceID == d.DeviceID));
            }
            Assert.AreEqual(user2_allDevices.Length, user1_devicesOnTransfer.Length + (user2_devicesPerNode * user2_tree.Sum(t => t.CountNodes())));



            //help cleanup
            for (int i = 0; i < _CreatedSites.Count; i++)
            {
                var site = _CreatedSites[i];

                if (site.Item1 == user1.UserID)
                {
                    if (user1_sitesOnTransfer.Any(s => s.Item2.Site.SiteID == site.Item2.SiteID))
                    {
                        _CreatedSites[i] = new Tuple<long, MainSite>(user2.UserID, site.Item2);
                    }
                }
            }
            for (int i = 0; i < _CreatedProjects.Count; i++)
            {
                var site = _CreatedProjects[i];

                if (site.Item1 == user1.UserID)
                {
                    if (user1_sitesOnTransfer.Any(s => s.Item2.Site.SiteID == site.Item2.SiteID))
                    {
                        _CreatedProjects[i] = new Tuple<long, MainSite>(user2.UserID, site.Item2);
                    }
                }
            }
        }

        [TestMethod()]
        public void LocalTransfer_Test()
        {
            //user 1
            int devicesPerNode = 5;
            var user1 = GeneralHelper.CreateTesterUser();
            var user1_tree = _CreateTree(3, 2, devicesPerNode, user1.UserID);

            //----------------------------------- BEFORE TRANSFER -----------------------------------
            int totalDevices = devicesPerNode * user1_tree.Sum(s => s.CountNodes());
            var devices = rep.GetDevicesSubscribed(user1.UserID);

            var sourceSite = user1_tree[0];
            var sourceSite_sites = sourceSite
                                    .Select()
                                    .ToArray();

            var targetSite = user1_tree[1];
            var targetSite_sites = targetSite
                                    .Select()
                                    .ToArray();

            //----------------------------------- START TRANSFER -----------------------------------
            Assert.IsTrue(rep.LocalTransfer(user1.UserID, sourceSite.Site.SiteID, targetSite.Site.SiteID));

            Assert.AreEqual(rep.SiteTransfer_GetAllPendings(sourceSite.Site.SiteID, user1.UserID).Length, 0);
            Assert.AreEqual(rep.SiteTransfer_GetAllPendings(targetSite.Site.SiteID, user1.UserID).Length, 0);


            //----------------------------------- TEST TRANSFER -----------------------------------
            var user1_updatedTree = rep.GetTree(user1.UserID, 1, 10000);
            Assert.AreEqual(user1_tree.Length - 1, user1_updatedTree.CurrentPageItems.Count(s => !s.ParentSiteID.HasValue));
            Assert.AreEqual(1, user1_updatedTree.CurrentPageItems.Count(s => s.SiteID == sourceSite.Site.SiteID));

            var sourceSite_updated = user1_updatedTree.CurrentPageItems.FirstOrDefault(s => s.SiteID == sourceSite.Site.SiteID);
            Assert.IsNotNull(sourceSite_updated);
            Assert.AreEqual(sourceSite_updated.ParentSiteID, targetSite.Site.SiteID);

            var devices_updated = rep.GetDevicesSubscribed(user1.UserID);
            Assert.AreEqual(totalDevices, devices_updated.Length);

            foreach (var d in devices)
            {
                Assert.AreEqual(1, devices_updated.Count(dd => dd.DeviceID == d.DeviceID));
            }
        }
    }
}