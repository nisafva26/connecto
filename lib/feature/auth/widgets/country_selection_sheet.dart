import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';

final List<Country> countryList = CountryService().getAll();

class CountrySelectorSheet extends StatefulWidget {
  final Country? selected;

  const CountrySelectorSheet({super.key, this.selected});

  @override
  State<CountrySelectorSheet> createState() => _CountrySelectorSheetState();
}

class _CountrySelectorSheetState extends State<CountrySelectorSheet> {
  List<Country> allCountries = countryList;
  List<Country> filteredCountries = countryList;
  final TextEditingController controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    controller.addListener(() {
      final query = controller.text.toLowerCase();
      setState(() {
        filteredCountries = allCountries
            .where((country) =>
                country.name.toLowerCase().contains(query) ||
                country.countryCode.toLowerCase().contains(query))
            .toList();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      builder: (_, scrollController) => Container(
        decoration: BoxDecoration(
            color: Color(0xFF091F1E),
            borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16), topRight: Radius.circular(16))),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: ListView(
            // crossAxisAlignment: CrossAxisAlignment.start,
            controller: scrollController,
            children: [
              SizedBox(height: 8),
              Center(
                child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: Colors.grey,
                        borderRadius: BorderRadius.circular(2))),
              ),
              SizedBox(height: 16),
              Text("Select country",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              SizedBox(height: 16),
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: "Find country",
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
              SizedBox(height: 24),
              if (widget.selected != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Selected location",
                      style:
                          TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    if (widget.selected != null) countryTile(widget.selected!),
                    // SizedBox(height: 16),
                  ],
                ),
              Divider(
                color: Color(0xff0E3735),
              ),
              SizedBox(
                height: 16,
              ),
              Text(
                "Other locations",
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
              SizedBox(
                height: 12,
              ),
              ListView.separated(
                separatorBuilder: (context, index) {
                  return Divider(
                    color: Color(0xff0E3735),
                  );
                },
                shrinkWrap: true,
                // controller: scrollController,
                physics: NeverScrollableScrollPhysics(),
                itemCount: filteredCountries.length,

                itemBuilder: (_, index) {
                  final country = filteredCountries[index];
                  return countryTile(country);
                },
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget countryTile(Country country) {
    return ListTile(
      leading: Text(country.flagEmoji, style: TextStyle(fontSize: 24)),
      title: Text(country.name),
      subtitle: Text("+${country.phoneCode}"),
      trailing: Icon(Icons.arrow_forward_ios, size: 16),
      onTap: () {
        Navigator.pop(context, country);
      },
    );
  }
}
