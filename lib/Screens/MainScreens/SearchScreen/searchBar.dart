import 'package:flutter/material.dart';
import 'package:fyp_project/Screens/MainScreens/SearchScreen/SearchResultScreen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SearchBarWithRecent extends StatefulWidget {
  @override
  _SearchBarWithRecentState createState() => _SearchBarWithRecentState();
}

class _SearchBarWithRecentState extends State<SearchBarWithRecent> {
  TextEditingController _controller = TextEditingController();
  List<String> recentSearches = [];
  List<String> filteredSuggestions = [];

  @override
  void initState() {
    super.initState();
    _loadRecentSearches();
    _controller.addListener(_filterSuggestions);
  }

  Future<void> _loadRecentSearches() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      recentSearches = prefs.getStringList('recentSearches') ?? [];
    });
  }
  void _clearAllRecentSearches() async {
    setState(() {
      recentSearches.clear();
      filteredSuggestions.clear();
    });
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('recentSearches');
  }

  Future<void> _saveRecentSearches() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setStringList('recentSearches', recentSearches);
  }

  void _filterSuggestions() {
    String input = _controller.text.toLowerCase();
    setState(() {
      filteredSuggestions = recentSearches
          .where((item) => item.toLowerCase().contains(input))
          .toList();
    });
  }

  void _onSuggestionTap(String suggestion) {
    _controller.text = suggestion;
    FocusScope.of(context).unfocus(); // Hide keyboard
  }

  void _onSearchSubmit(String value) {
    if (value.trim().isEmpty) return;

    setState(() {
      recentSearches.remove(value);
      recentSearches.insert(0, value);
      if (recentSearches.length > 5) recentSearches.removeLast();
    });

    _saveRecentSearches();
    FocusScope.of(context).unfocus();

    // Navigate to the search results screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context)=>SearchResultsScreen(searchQuery: value)
        // builder: (context) => SearchResultsScreen(searchQuery: value),
      ),
    );
  }


  void _removeSuggestion(String item) {
    setState(() {
      recentSearches.remove(item);
      filteredSuggestions.remove(item);
    });
    _saveRecentSearches();
  }

  @override
  Widget build(BuildContext context) {
    final showSuggestions =
        _controller.text.isNotEmpty && filteredSuggestions.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _controller,
          onSubmitted: _onSearchSubmit,
          decoration: InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'Search for charging station',
            filled: true,
            fillColor: Colors.grey.shade200,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 10),
        if (showSuggestions)
          ...filteredSuggestions.map(
                (suggestion) => ListTile(
              title: Text(suggestion),
              trailing: IconButton(
                icon: Icon(Icons.clear, size: 18),
                onPressed: () => _removeSuggestion(suggestion),
              ),
              onTap: () => _onSuggestionTap(suggestion),
            ),
          ),
        if (_controller.text.isEmpty && recentSearches.isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Recent Searches",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextButton(
                    onPressed: _clearAllRecentSearches,
                    child: const Text(
                      "Clear All",
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
              ...recentSearches.map(

              (suggestion) => ListTile(
                  title: Text(suggestion),
                  trailing: IconButton(
                    icon: Icon(Icons.clear, size: 18),
                    onPressed: () => _removeSuggestion(suggestion),
                  ),
                  onTap: () => _onSuggestionTap(suggestion),
                ),
              ),
            ],
          ),
      ],
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
